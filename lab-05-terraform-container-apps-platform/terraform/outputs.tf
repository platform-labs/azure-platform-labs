output "container_app_id" { value = azurerm_container_app.wallet_api.id }
output "container_app_fqdn" { value = azurerm_container_app.wallet_api.ingress[0].fqdn }

