// ============================================================
//  Parameter File: Development Environment
//  Usage: az deployment group create \
//           --resource-group rg-oms-d365-integration-dev \
//           --template-file ../main.bicep \
//           --parameters @dev.bicepparam
// ============================================================

using '../main.bicep'

// ── Environment ───────────────────────────────────────────────
param environment = 'dev'

// ── Azure Region ──────────────────────────────────────────────
//  West Europe for all environments (keep latency consistent with D365 instance)
param location = 'westeurope'

// ── Resource Tags ─────────────────────────────────────────────
param tags = {
  project:         'oms-d365-integration'
  environment:     'dev'
  costCenter:      'IT-DEV-001'
  managedBy:       'bicep'
  team:            'azure-integration'
  deployedBy:      'ci-cd-pipeline'
  owner:           'integration-team@company.com'
}
