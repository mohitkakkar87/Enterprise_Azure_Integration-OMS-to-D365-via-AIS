// ============================================================
//  Module: Cosmos DB
//  Creates: Account (NoSQL), Database (oms-integration-db),
//           Container (oms-orders) with /orderId partition key,
//           composite index on [processingStatus, ingestedAt]
// ============================================================

@description('Deployment environment')
param environment string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

// ── Throughput per environment ────────────────────────────────
//  dev : 400 RU/s manual — cost conscious, no SLA requirement
//  uat : 400 RU/s manual — mirrors dev for test parity
//  prod: autoscale 100–4000 RU/s — handles peak ingestion bursts
//        without over-provisioning

var throughputSettings = environment == 'prod'
  ? {
      autoscaleSettings: {
        maxThroughput: 4000
      }
    }
  : {
      throughput: 400
    }

// ── Cosmos DB Account ─────────────────────────────────────────
//  kind: GlobalDocumentDB — NoSQL API
//  Session consistency: best trade-off for our workload.
//    - Function 1 (write) and Function 2 (read same session) will
//      always see their own writes due to session token forwarding.
//    - Strong consistency would double the RU cost and add ~10ms
//      latency — not justified for a batch integration scenario.
//  publicNetworkAccess: prod uses Private Endpoint;
//                       dev/uat allow public for ease of debugging

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: 'cosmos-oms-integration-${environment}'
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
      maxStalenessPrefix: 100
      maxIntervalInSeconds: 5
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: environment == 'prod' ? true : false
      }
    ]
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    isVirtualNetworkFilterEnabled: false
    publicNetworkAccess: environment == 'prod' ? 'Disabled' : 'Enabled'
    capabilities: []
    enableFreeTier: false
    disableLocalAuth: false  // Managed Identity is primary; local auth for tooling
    minimalTlsVersion: 'Tls12'
  }
  tags: tags
}

// ── Database ───────────────────────────────────────────────────

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-04-15' = {
  parent: cosmosAccount
  name: 'oms-integration-db'
  properties: {
    resource: {
      id: 'oms-integration-db'
    }
  }
}

// ── Container: oms-orders ─────────────────────────────────────
//  Partition Key: /orderId
//    Why /orderId?
//    1. Every order is unique → perfect cardinality → even distribution
//    2. All CRUD operations are per-orderId → zero cross-partition writes
//    3. Idempotency check (READ then UPSERT) is always single-partition
//    4. TTL of 30 days (2592000s) auto-removes processed records
//
//  Index Policy:
//    Default (*) indexing is ON.
//    Composite index on [processingStatus ASC, ingestedAt ASC] is
//    required for Function 2's query:
//      SELECT * FROM c WHERE c.processingStatus = 'Pending'
//      ORDER BY c.ingestedAt ASC
//    Without this composite index, Cosmos DB throws a query error
//    when combining filter + order by on different fields.

resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-04-15' = {
  parent: database
  name: 'oms-orders'
  properties: {
    resource: {
      id: 'oms-orders'
      partitionKey: {
        paths: ['/orderId']
        kind: 'Hash'
        version: 2  // v2 = full hash — better distribution than v1
      }
      defaultTtl: 2592000   // 30 days in seconds
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
          {
            path: '/omsEvent/*'   // Large nested payload — exclude from index to save RU
          }
        ]
        compositeIndexes: [
          [
            {
              path: '/processingStatus'
              order: 'ascending'
            }
            {
              path: '/ingestedAt'
              order: 'ascending'
            }
          ]
          [
            {
              path: '/processingStatus'
              order: 'ascending'
            }
            {
              path: '/batchId'
              order: 'ascending'
            }
          ]
        ]
      }
    }
    options: throughputSettings
  }
}

// ── Outputs ────────────────────────────────────────────────────

@description('Cosmos DB account endpoint')
output endpoint string = cosmosAccount.documentEndpoint

@description('Cosmos DB account name')
output accountName string = cosmosAccount.name

@description('Cosmos DB account resource ID')
output accountId string = cosmosAccount.id

@description('Database name')
output databaseName string = database.name

@description('Container name')
output containerName string = container.name
