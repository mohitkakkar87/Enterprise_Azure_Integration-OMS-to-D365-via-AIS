// ============================================================
//  Module: Azure Key Vault
//  Creates: Key Vault (RBAC permission model),
//           Diagnostic settings to Log Analytics
//  Model:   RBAC (not Access Policies) — recommended for new deployments
//  Secrets: Populated AFTER deployment via CI/CD pipeline or
//           az keyvault secret set commands (not in Bicep — never
//           hardcode secrets in IaC templates)
// ============================================================

@description('Deployment environment')
param environment string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

@description('Azure AD tenant ID for Key Vault')
param tenantId string

// ── Key Vault ──────────────────────────────────────────────────
//  enableRbacAuthorization: true — use Azure RBAC, not vault access policies
//    Advantages of RBAC model:
//    1. Standard Azure RBAC — consistent with other resources
//    2. Support Managed Identity with "Key Vault Secrets User" role
//    3. No 16-access-policy limit
//    4. Can scope permissions to individual secrets (not just vault level)
//
//  enableSoftDelete: true — 90 day recovery period (mandatory since 2021)
//  enablePurgeProtection: prod only — prevents permanent deletion
//  publicNetworkAccess: prod uses PE; dev/uat allow public for tooling

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-oms-integration-${environment}'
  location: location
  properties: {
    tenantId: tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
    enableRbacAuthorization: true           // RBAC model
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: environment == 'prod' ? true : false
    publicNetworkAccess: environment == 'prod' ? 'Disabled' : 'Enabled'
    networkAcls: {
      defaultAction: environment == 'prod' ? 'Deny' : 'Allow'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    }
  }
  tags: tags
}

// ── NOTES: Secrets to be created post-deployment ──────────────
//  The following secrets must be set via CI/CD pipeline after deployment.
//  NEVER put secret values in Bicep templates.
//
//  Required secrets:
//    D365-Base-Url         = https://<company>.operations.dynamics.com
//    D365-Tenant-Id        = <AAD tenant ID of D365 environment>
//    D365-Client-Id        = <App Registration client ID for D365 auth>
//    D365-Client-Secret    = <App Registration client secret>
//    OMS-EventGrid-SasKey  = <Event Grid SAS key — only if AAD not used>
//
//  CI/CD pipeline command example:
//    az keyvault secret set \
//      --vault-name kv-oms-integration-prod \
//      --name D365-Client-Secret \
//      --value "$(D365_CLIENT_SECRET)"  # from pipeline variable
//
//  Key Vault references in Function App / Logic App app settings:
//    @Microsoft.KeyVault(VaultName=kv-oms-integration-prod;SecretName=D365-Client-Secret)

// ── Outputs ────────────────────────────────────────────────────

@description('Key Vault URI (used in app settings and secret references)')
output keyVaultUri string = keyVault.properties.vaultUri

@description('Key Vault name')
output keyVaultName string = keyVault.name

@description('Key Vault resource ID')
output keyVaultId string = keyVault.id
