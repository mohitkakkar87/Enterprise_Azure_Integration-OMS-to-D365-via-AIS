// ============================================================
//  Module: Function App (Windows, .NET 8 Isolated, v4)
//  Creates: App Service Plan (Consumption Y1), Function App,
//           App Settings (Key Vault references for secrets),
//           System-Assigned Managed Identity
// ============================================================

@description('Deployment environment')
param environment string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

@description('Storage account name for Function App internal storage (AzureWebJobsStorage)')
param storageAccountName string

@description('Application Insights connection string')
param appInsightsConnectionString string

@description('Cosmos DB endpoint URL')
param cosmosDbEndpoint string

@description('Cosmos DB account name (for role assignment reference)')
param cosmosDbAccountName string

@description('Service Bus namespace name')
param serviceBusNamespaceName string

@description('Service Bus namespace resource ID (for RBAC)')
param serviceBusNamespaceId string

@description('Key Vault URI')
param keyVaultUri string

@description('Key Vault name (for Key Vault reference syntax)')
param keyVaultName string

// ── Reference existing Storage Account ───────────────────────

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

// ── App Service Plan — Consumption Y1 ─────────────────────────
//  Consumption plan chosen because:
//  - Function 1 (ServiceBusTrigger) scales elastically with queue depth
//  - Function 2 (Timer, every 4h) has very low instance requirements
//  - Pay-per-execution — cost-optimal for our event volume
//  - For prod at >1M events/month, consider Premium EP1 for VNet, VNET trigger

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: 'asp-oms-integration-${environment}'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  kind: 'functionapp'
  properties: {
    reserved: false   // Windows host
  }
  tags: tags
}

// ── Function App ───────────────────────────────────────────────

resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: 'func-oms-integration-${environment}'
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'   // Enables Managed Identity
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      netFrameworkVersion: 'v8.0'
      use32BitWorkerProcess: false
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        // ── Azure Functions runtime ─────────────────────────
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
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
          value: 'func-oms-integration-${environment}'
        }
        // ── Application Insights ─────────────────────────────
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        // ── Service Bus — Managed Identity (no connection string) ─
        {
          name: 'ServiceBusConnection__fullyQualifiedNamespace'
          value: '${serviceBusNamespaceName}.servicebus.windows.net'
        }
        {
          name: 'ServiceBusTopicName'
          value: 'oms-orders-topic'
        }
        {
          name: 'ServiceBusSubscriptionName'
          value: 'oms-d365-subscription'
        }
        // ── Cosmos DB — Managed Identity (no key) ────────────
        {
          name: 'CosmosDbEndpoint'
          value: cosmosDbEndpoint
        }
        {
          name: 'CosmosDbDatabaseName'
          value: 'oms-integration-db'
        }
        {
          name: 'CosmosDbContainerName'
          value: 'oms-orders'
        }
        // ── Blob Storage — Managed Identity ──────────────────
        {
          name: 'BlobStorageEndpoint'
          value: 'https://${storageAccount.name}.blob.${az.environment().suffixes.storage}'
        }
        {
          name: 'BlobContainerName'
          value: 'oms-d365-payloads'
        }
        // ── Key Vault Reference — D365 credentials ───────────
        //  Secret never appears in app settings. KV reference
        //  is resolved at runtime by the Functions runtime.
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

@description('Function App name')
output functionAppName string = functionApp.name

@description('Function App resource ID')
output functionAppId string = functionApp.id

@description('Managed Identity principal ID (for RBAC assignments in main.bicep)')
output principalId string = functionApp.identity.principalId

@description('Function App default hostname')
output defaultHostname string = functionApp.properties.defaultHostName
