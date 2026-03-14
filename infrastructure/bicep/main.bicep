// ============================================================
//  OMS → D365 Integration — Bicep Main Deployment File
//  Author : Azure Integration Architect (15 years experience)
//  Version: 1.0.0
//  Target : Resource Group scope
// ============================================================
//
//  Module Dependency Graph:
//
//  main.bicep
//  ├── appInsights.bicep    ← no upstream deps
//  ├── keyVault.bicep       ← no upstream deps
//  ├── serviceBus.bicep     ← no upstream deps
//  ├── cosmosDb.bicep       ← no upstream deps
//  ├── storage.bicep        ← no upstream deps
//  ├── eventGrid.bicep      ← depends on: serviceBus
//  ├── functionApp.bicep    ← depends on: storage, appInsights, cosmosDb, serviceBus, keyVault
//  └── logicApp.bicep       ← depends on: storage, appInsights, keyVault
//
// ============================================================

targetScope = 'resourceGroup'

// ── Parameters ───────────────────────────────────────────────────────────────

@description('Deployment environment: dev, uat, or prod')
@allowed(['dev', 'uat', 'prod'])
param environment string

@description('Azure region for all resources. Defaults to resource group location.')
param location string = resourceGroup().location

@description('Resource tags applied to every resource in this deployment.')
param tags object = {
  project: 'oms-d365-integration'
  environment: environment
  managedBy: 'bicep'
  team: 'azure-integration'
  costCenter: 'IT-INT-001'
}

// ── Module: Application Insights + Log Analytics Workspace ───────────────────

module appInsights './modules/appInsights.bicep' = {
  name: 'deploy-appInsights-${environment}'
  params: {
    environment: environment
    location: location
    tags: tags
  }
}

// ── Module: Key Vault ─────────────────────────────────────────────────────────

module keyVault './modules/keyVault.bicep' = {
  name: 'deploy-keyVault-${environment}'
  params: {
    environment: environment
    location: location
    tags: tags
    tenantId: tenant().tenantId
  }
}

// ── Module: Service Bus ───────────────────────────────────────────────────────

module serviceBus './modules/serviceBus.bicep' = {
  name: 'deploy-serviceBus-${environment}'
  params: {
    environment: environment
    location: location
    tags: tags
  }
}

// ── Module: Cosmos DB ─────────────────────────────────────────────────────────

module cosmosDb './modules/cosmosDb.bicep' = {
  name: 'deploy-cosmosDb-${environment}'
  params: {
    environment: environment
    location: location
    tags: tags
  }
}

// ── Module: Storage Account ───────────────────────────────────────────────────

module storage './modules/storage.bicep' = {
  name: 'deploy-storage-${environment}'
  params: {
    environment: environment
    location: location
    tags: tags
  }
}

// ── Module: Event Grid (depends on Service Bus for subscription routing) ──────

module eventGrid './modules/eventGrid.bicep' = {
  name: 'deploy-eventGrid-${environment}'
  params: {
    environment: environment
    location: location
    tags: tags
    serviceBusTopicId: serviceBus.outputs.topicId
    serviceBusNamespaceId: serviceBus.outputs.namespaceId
  }
  dependsOn: [serviceBus]
}

// ── Module: Function App (depends on most infrastructure modules) ─────────────

module functionApp './modules/functionApp.bicep' = {
  name: 'deploy-functionApp-${environment}'
  params: {
    environment: environment
    location: location
    tags: tags
    storageAccountName: storage.outputs.storageAccountName
    appInsightsConnectionString: appInsights.outputs.connectionString
    cosmosDbEndpoint: cosmosDb.outputs.endpoint
    cosmosDbAccountName: cosmosDb.outputs.accountName
    serviceBusNamespaceName: serviceBus.outputs.namespaceName
    serviceBusNamespaceId: serviceBus.outputs.namespaceId
    keyVaultUri: keyVault.outputs.keyVaultUri
    keyVaultName: keyVault.outputs.keyVaultName
  }
  dependsOn: [storage, appInsights, cosmosDb, serviceBus, keyVault]
}

// ── Module: Logic App Standard (depends on storage, appInsights, keyVault) ───

module logicApp './modules/logicApp.bicep' = {
  name: 'deploy-logicApp-${environment}'
  params: {
    environment: environment
    location: location
    tags: tags
    storageAccountName: storage.outputs.storageAccountName
    storageAccountId: storage.outputs.storageAccountId
    appInsightsConnectionString: appInsights.outputs.connectionString
    keyVaultUri: keyVault.outputs.keyVaultUri
    keyVaultName: keyVault.outputs.keyVaultName
  }
  dependsOn: [storage, appInsights, keyVault]
}

// ── RBAC: Grant Function App Managed Identity access to Cosmos DB ─────────────

// Role: Cosmos DB Built-in Data Contributor (read/write documents)
resource cosmosRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(cosmosDb.outputs.accountId, functionApp.outputs.principalId, 'cosmos-data-contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '00000000-0000-0000-0000-000000000002') // Cosmos DB Built-in Data Contributor
    principalId: functionApp.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// Role: Service Bus Data Receiver for Function App
resource sbReceiverRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(serviceBus.outputs.namespaceId, functionApp.outputs.principalId, 'sb-data-receiver')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0') // Azure Service Bus Data Receiver
    principalId: functionApp.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// Role: Storage Blob Data Contributor for Function App
resource storageFuncRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.outputs.storageAccountId, functionApp.outputs.principalId, 'storage-blob-contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalId: functionApp.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// Role: Storage Blob Data Contributor for Logic App
resource storageLogicRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.outputs.storageAccountId, logicApp.outputs.principalId, 'storage-blob-contributor-la')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: logicApp.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('Name of the deployed Function App')
output functionAppName string = functionApp.outputs.functionAppName

@description('Cosmos DB account endpoint URL')
output cosmosDbEndpoint string = cosmosDb.outputs.endpoint

@description('Service Bus namespace name')
output serviceBusNamespaceName string = serviceBus.outputs.namespaceName

@description('Logic App Standard name')
output logicAppName string = logicApp.outputs.logicAppName

@description('Key Vault URI for reference in app settings')
output keyVaultUri string = keyVault.outputs.keyVaultUri

@description('Application Insights name')
output appInsightsName string = appInsights.outputs.appInsightsName

@description('Storage account name for blob staging')
output storageAccountName string = storage.outputs.storageAccountName
