// ============================================================
//  Module: Application Insights + Log Analytics Workspace
//  Creates: Log Analytics Workspace (90-day retention),
//           Application Insights (workspace-based, modern mode)
// ============================================================

@description('Deployment environment')
param environment string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

// ── Log Analytics Workspace ────────────────────────────────────
//  retentionInDays: 90 for prod (90 free under Capacity model),
//                  30 for dev/uat (minimum)
//  sku: PerGB2018 — pay-per-GB, most cost-effective for variable volumes

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law-oms-integration-${environment}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: environment == 'prod' ? 90 : 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: tags
}

// ── Application Insights ───────────────────────────────────────
//  kind: web — works for all Azure services (Functions, Logic Apps)
//  Application_Type: web — standard instrumentation
//  WorkspaceResourceId: links to Log Analytics (workspace-based mode)
//    Classic AI (without workspace) is deprecated since 2024.
//    Workspace-based AI stores logs in Log Analytics for unified querying.
//
//  SamplingPercentage: 100 in dev (all telemetry), 50 in prod
//    (reduce ingestion cost while keeping statistical accuracy)
//  DisableIpMasking: false — GDPR compliance (mask IPs)

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-oms-integration-${environment}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    RetentionInDays: environment == 'prod' ? 90 : 30
    SamplingPercentage: environment == 'prod' ? 50 : 100
    DisableIpMasking: false
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: tags
}

// ── Outputs ────────────────────────────────────────────────────

@description('Application Insights connection string (preferred over instrumentation key)')
output connectionString string = appInsights.properties.ConnectionString

@description('Application Insights instrumentation key (legacy, use connectionString)')
output instrumentationKey string = appInsights.properties.InstrumentationKey

@description('Application Insights name')
output appInsightsName string = appInsights.name

@description('Application Insights resource ID')
output appInsightsId string = appInsights.id

@description('Log Analytics Workspace resource ID')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id

@description('Log Analytics Workspace name')
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
