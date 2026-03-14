terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "omstfstate"
    container_name       = "tfstate"
    key                  = "oms-d365-integration.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}

data "azurerm_client_config" "current" {}

# ══════════════════════════════════════════════════════════════
# Resource Group
# ══════════════════════════════════════════════════════════════
resource "azurerm_resource_group" "integration" {
  name     = "rg-oms-d365-integration-${var.environment}"
  location = var.location
  tags     = local.common_tags
}

# ══════════════════════════════════════════════════════════════
# Service Bus Namespace, Topic, Subscription
# ══════════════════════════════════════════════════════════════
resource "azurerm_servicebus_namespace" "integration" {
  name                = "sb-oms-integration-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.integration.name
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_servicebus_topic" "oms_orders" {
  name                                    = "oms-orders-topic"
  namespace_id                            = azurerm_servicebus_namespace.integration.id
  enable_partitioning                     = true
  default_message_ttl                     = "P14D"
  duplicate_detection_history_time_window = "PT10M"
}

resource "azurerm_servicebus_subscription" "d365" {
  name                                 = "oms-d365-subscription"
  topic_id                             = azurerm_servicebus_topic.oms_orders.id
  max_delivery_count                   = 10
  lock_duration                        = "PT5M"
  dead_lettering_on_message_expiration = true
  default_message_ttl                  = "P14D"
}

# ══════════════════════════════════════════════════════════════
# Cosmos DB Account, Database, Container
# ══════════════════════════════════════════════════════════════
resource "azurerm_cosmosdb_account" "integration" {
  name                = "cosmos-oms-integration-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.integration.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 5
    max_staleness_prefix    = 100
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  tags = local.common_tags
}

resource "azurerm_cosmosdb_sql_database" "integration" {
  name                = "oms-integration-db"
  resource_group_name = azurerm_resource_group.integration.name
  account_name        = azurerm_cosmosdb_account.integration.name
}

resource "azurerm_cosmosdb_sql_container" "orders" {
  name                = "oms-orders"
  resource_group_name = azurerm_resource_group.integration.name
  account_name        = azurerm_cosmosdb_account.integration.name
  database_name       = azurerm_cosmosdb_sql_database.integration.name
  partition_key_path  = "/orderId"
  default_ttl         = 2592000 # 30 days

  autoscale_settings {
    max_throughput = 4000
  }

  indexing_policy {
    indexing_mode = "consistent"
    included_path { path = "/processingStatus/?" }
    included_path { path = "/ingestedAt/?" }
    included_path { path = "/batchId/?" }
    included_path { path = "/orderId/?" }
    excluded_path { path = "/products/*" }
    excluded_path { path = "/\"_etag\"/?" }
  }
}

# ══════════════════════════════════════════════════════════════
# Storage Account + Blob Containers
# ══════════════════════════════════════════════════════════════
resource "azurerm_storage_account" "integration" {
  name                     = "saomsd365integ${var.environment}"
  resource_group_name      = azurerm_resource_group.integration.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = local.common_tags
}

resource "azurerm_storage_container" "payloads" {
  name                  = "oms-d365-payloads"
  storage_account_name  = azurerm_storage_account.integration.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "processed" {
  name                  = "oms-d365-processed"
  storage_account_name  = azurerm_storage_account.integration.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "failed" {
  name                  = "oms-d365-failed"
  storage_account_name  = azurerm_storage_account.integration.name
  container_access_type = "private"
}

# ══════════════════════════════════════════════════════════════
# Application Insights + Log Analytics
# ══════════════════════════════════════════════════════════════
resource "azurerm_log_analytics_workspace" "integration" {
  name                = "law-oms-integration-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.integration.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

resource "azurerm_application_insights" "integration" {
  name                = "ai-oms-integration-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.integration.name
  workspace_id        = azurerm_log_analytics_workspace.integration.id
  application_type    = "web"
  tags                = local.common_tags
}

# ══════════════════════════════════════════════════════════════
# Key Vault — All secrets stored here. No plain text in app settings.
# ══════════════════════════════════════════════════════════════
resource "azurerm_key_vault" "integration" {
  name                       = "kv-oms-integ-${var.environment}"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.integration.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 30
  purge_protection_enabled   = true
  tags                       = local.common_tags
}

# ══════════════════════════════════════════════════════════════
# App Service Plan (Consumption — Y1 for dev, EP1 for prod)
# ══════════════════════════════════════════════════════════════
resource "azurerm_service_plan" "functions" {
  name                = "asp-oms-functions-${var.environment}"
  resource_group_name = azurerm_resource_group.integration.name
  location            = var.location
  os_type             = "Windows"
  sku_name            = var.environment == "prod" ? "EP1" : "Y1"
  tags                = local.common_tags
}

# ══════════════════════════════════════════════════════════════
# Function App — OMS Integration (both functions in one app)
# ══════════════════════════════════════════════════════════════
resource "azurerm_storage_account" "functions" {
  name                     = "saomsfa${var.environment}"
  resource_group_name      = azurerm_resource_group.integration.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = local.common_tags
}

resource "azurerm_windows_function_app" "integration" {
  name                       = "func-oms-integration-${var.environment}"
  resource_group_name        = azurerm_resource_group.integration.name
  location                   = var.location
  service_plan_id            = azurerm_service_plan.functions.id
  storage_account_name       = azurerm_storage_account.functions.name
  storage_account_access_key = azurerm_storage_account.functions.primary_access_key

  site_config {
    application_stack {
      dotnet_version              = "v8.0"
      use_dotnet_isolated_runtime = true
    }
    always_on = var.environment == "prod" ? true : false
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"       = "dotnet-isolated"
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.integration.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.integration.connection_string
    "AZURE_ENVIRONMENT"              = var.environment

    # Key Vault references — no plain text secrets in app settings
    "ServiceBusConnection"    = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault.integration.vault_uri}secrets/ServiceBusConnection/)"
    "CosmosDbConnection"      = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault.integration.vault_uri}secrets/CosmosDbConnection/)"
    "BlobStorageConnection"   = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault.integration.vault_uri}secrets/BlobStorageConnection/)"

    # Configuration
    "CosmosDbDatabaseName"      = "oms-integration-db"
    "CosmosDbContainerName"     = "oms-orders"
    "BlobContainerName"         = "oms-d365-payloads"
    "BlobProcessedContainerName"= "oms-d365-processed"
    "ServiceBusTopicName"       = "oms-orders-topic"
    "ServiceBusSubscriptionName"= "oms-d365-subscription"
  }

  tags = local.common_tags
}

# Grant Function App Managed Identity access to Key Vault
resource "azurerm_key_vault_access_policy" "function_app" {
  key_vault_id = azurerm_key_vault.integration.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_windows_function_app.integration.identity[0].principal_id

  secret_permissions = ["Get", "List"]
}

# ══════════════════════════════════════════════════════════════
# Locals
# ══════════════════════════════════════════════════════════════
locals {
  common_tags = {
    Project     = "OMS-D365-Integration"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = "integration-team@company.com"
    CostCentre  = "IT-Integration"
  }
}
