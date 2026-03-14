// ============================================================
//  Module: Logic App Standard
//  Creates: App Service Plan (WS1 Workflow Standard),
//           Logic App Standard site, System-Assigned MI
//  Note:    Logic App Standard requires a dedicated plan (not Consumption).
//           WS1 is the entry-level Workflow Standard SKU.
// ============================================================

@description('Deployment environment')
param environment string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

@description('Storage account name (Logic App Standard requires storage)')
param storageAccountName string

@description('Storage account resource ID')
param storageAccountId string

@description('Application Insights connection string')
param appInsightsConnectionString string

@description('Key Vault URI for secret references')
param keyVaultUri string

@description('Key Vault name for reference syntax')
param keyVaultName string

// ── Reference existing Storage Account ───────────────────────

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

// ── App Service Plan — Workflow Standard WS1 ──────────────────
//  Logic App Standard requires a dedicated ASP (not Consumption).
//  WS1 (1 vCore, 3.5 GB RAM) is suitable for our delivery workflow.
//  For prod with high concurrency, consider WS2 or WS3.

resource logicAppPlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: 'asp-la-oms-integration-${environment}'
  location: location
  sku: {
    name: 'WS1'
    tier: 'WorkflowStandard'
  }
  kind: 'windows'
  properties: {
    reserved: false
    targetWorkerCount: environment == 'prod' ? 2 : 1
    targetWorkerSizeId: 0
    maximumElasticWorkerCount: environment == 'prod' ? 4 : 2
  }
  tags: tags
}

// ── Logic App Standard ─────────────────────────────────────────

resource logicApp 'Microsoft.Web/sites@2023-01-01' = {
  name: 'la-oms-d365-delivery-${environment}'
  location: location
  kind: 'functionapp,workflowapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: logicAppPlan.id
    httpsOnly: true
    siteConfig: {
      netFrameworkVersion: 'v6.0'
      use32BitWorkerProcess: false
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        // ── Logic App Standard runtime ──────────────────────
        {
          name: 'APP_KIND'
          value: 'workflowApp'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~18'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${az.environment().suffixes.storage}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${az.environment().suffixes.storage}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: 'la-oms-d365-delivery-${environment}'
        }
        // ── Application Insights ─────────────────────────────
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        // ── Blob Storage (for reading ZIP staging container) ─
        {
          name: 'BlobStorageEndpoint'
          value: 'https://${storageAccount.name}.blob.${az.environment().suffixes.storage}'
        }
        {
          name: 'BlobStagingContainer'
          value: 'oms-d365-payloads'
        }
        // ── D365 credentials via Key Vault references ────────
        {
          name: 'D365BaseUrl'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=D365-Base-Url)'
        }
        {
          name: 'D365TenantId'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=D365-Tenant-Id)'
        }
        {
          name: 'D365ClientId'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=D365-Client-Id)'
        }
        {
          name: 'D365ClientSecret'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=D365-Client-Secret)'
        }
        // ── Environment ───────────────────────────────────────
        {
          name: 'Environment'
          value: environment
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
    }
  }
  tags: tags
}

// ── Outputs ────────────────────────────────────────────────────

@description('Logic App Standard name')
output logicAppName string = logicApp.name

@description('Logic App resource ID')
output logicAppId string = logicApp.id

@description('Managed Identity principal ID (for RBAC assignments)')
output principalId string = logicApp.identity.principalId

@description('Logic App default hostname')
output defaultHostname string = logicApp.properties.defaultHostName
