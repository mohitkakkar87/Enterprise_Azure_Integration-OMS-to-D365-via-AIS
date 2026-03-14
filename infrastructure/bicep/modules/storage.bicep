// ============================================================
//  Module: Storage Account
//  Creates: Storage Account (ZRS in prod, LRS in dev/uat),
//           Blob Container (oms-d365-payloads) for ZIP staging,
//           Lifecycle management policy (delete blobs after 7 days)
// ============================================================

@description('Deployment environment')
param environment string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

// ── Storage Account ────────────────────────────────────────────
//  sku: ZRS in prod for zone-redundant durability (3 zones)
//       LRS in dev/uat to reduce cost
//  kind: StorageV2 — supports Blob, Queue, Table, File
//  accessTier: Hot — ZIP files are written and read within hours
//  minimumTlsVersion: TLS1_2 — security baseline
//  allowBlobPublicAccess: false — no public blob access ever

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'saomsintegration${environment}'   // max 24 chars, no hyphens
  location: location
  sku: {
    name: environment == 'prod' ? 'Standard_ZRS' : 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    allowSharedKeyAccess: true    // Required for AzureWebJobsStorage until MI storage is fully supported
    networkAcls: {
      defaultAction: environment == 'prod' ? 'Deny' : 'Allow'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    }
  }
  tags: tags
}

// ── Blob Service ───────────────────────────────────────────────

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: environment == 'prod' ? 14 : 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    isVersioningEnabled: environment == 'prod' ? true : false
  }
}

// ── Container: oms-d365-payloads ──────────────────────────────
//  This container holds the ZIP packages that Logic App reads
//  and sends to D365 via DIXF import. After successful delivery,
//  Logic App deletes the blob.

resource stagingContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'oms-d365-payloads'
  properties: {
    publicAccess: 'None'
    metadata: {
      purpose: 'staging'
      managedBy: 'function-app-oms-transform'
    }
  }
}

// ── Lifecycle Management Policy ───────────────────────────────
//  Safety net: delete any blobs in staging container that are
//  older than 7 days (production SLA is delivery within 4h15m,
//  so 7 days means an unprocessed blob is a definite failure).

resource lifecyclePolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          name: 'delete-old-staging-zips'
          enabled: true
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: ['blockBlob']
              prefixMatch: ['oms-d365-payloads/']
            }
            actions: {
              baseBlob: {
                delete: {
                  daysAfterModificationGreaterThan: 7
                }
              }
            }
          }
        }
      ]
    }
  }
}

// ── Outputs ────────────────────────────────────────────────────

@description('Storage account name')
output storageAccountName string = storageAccount.name

@description('Storage account resource ID')
output storageAccountId string = storageAccount.id

@description('Staging container name')
output stagingContainerName string = stagingContainer.name

@description('Blob service primary endpoint')
output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob
