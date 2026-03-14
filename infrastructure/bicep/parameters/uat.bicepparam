// ============================================================
//  Parameter File: UAT (User Acceptance Testing) Environment
//  Usage: az deployment group create \
//           --resource-group rg-oms-d365-integration-uat \
//           --template-file ../main.bicep \
//           --parameters @uat.bicepparam
// ============================================================

using '../main.bicep'

// ── Environment ───────────────────────────────────────────────
param environment = 'uat'

// ── Azure Region ──────────────────────────────────────────────
param location = 'westeurope'

// ── Resource Tags ─────────────────────────────────────────────
param tags = {
  project:         'oms-d365-integration'
  environment:     'uat'
  costCenter:      'IT-UAT-001'
  managedBy:       'bicep'
  team:            'azure-integration'
  deployedBy:      'ci-cd-pipeline'
  owner:           'integration-team@company.com'
  // UAT-specific tag for test data management
  testEnvironment: 'true'
  dataClassification: 'non-production'
}
