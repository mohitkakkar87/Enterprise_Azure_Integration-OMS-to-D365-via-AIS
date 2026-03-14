output "function_app_name" {
  value       = azurerm_windows_function_app.integration.name
  description = "Name of the deployed Function App"
}

output "cosmos_db_endpoint" {
  value       = azurerm_cosmosdb_account.integration.endpoint
  description = "Cosmos DB account endpoint"
}

output "app_insights_instrumentation_key" {
  value       = azurerm_application_insights.integration.instrumentation_key
  sensitive   = true
  description = "Application Insights instrumentation key"
}

output "storage_account_name" {
  value       = azurerm_storage_account.integration.name
  description = "Name of the integration storage account"
}

output "key_vault_uri" {
  value       = azurerm_key_vault.integration.vault_uri
  description = "Key Vault URI for secret references"
}
