// ============================================================
//  Parameter File: Production Environment
//  Usage: az deployment group create \
//           --resource-group rg-oms-d365-integration-prod \
//           --template-file ../main.bicep \
//           --parameters @prod.bicepparam
//
//  ⚠️  IMPORTANT: Production deployments require:
//    1. Approval gate in CI/CD pipeline (manual approval)
//    2. Deployment during off-peak window (00:00–04:00 UTC)
//    3. Pre-deployment health check of existing resources
//    4. Post-deployment smoke test (validate Logic App run)
// ============================================================

using '../main.bicep'

// ── Environment ───────────────────────────────────────────────
param environment = 'prod'

// ── Azure Region ──────────────────────────────────────────────
//  West Europe — primary region (D365 F&O is also in West Europe)
param location = 'westeurope'

// ── Resource Tags ─────────────────────────────────────────────
//  Production tags include compliance and ownership metadata
//  required by the company's cloud governance policy.
param tags = {
  project:          'oms-d365-integration'
  environment:      'prod'
  costCenter:       'IT-PROD-001'
  managedBy:        'bicep'
  team:             'azure-integration'
  deployedBy:       'ci-cd-pipeline'
  owner:            'integration-team@company.com'
  slaTarget:        '99.9'
  dataClassification: 'confidential'
  complianceScope:  'SOC2'
  businessUnit:     'supply-chain'
  criticalityLevel: 'high'
}
