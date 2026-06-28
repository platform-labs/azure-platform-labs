output "vnet_id" { value = azurerm_virtual_network.main.id }
output "public_subnet_ids" { value = azurerm_subnet.public[*].id }
output "private_app_subnet_ids" { value = azurerm_subnet.private_app[*].id }
output "private_data_subnet_ids" { value = azurerm_subnet.private_data[*].id }
output "app_nsg_id" { value = azurerm_network_security_group.app.id }
output "data_nsg_id" { value = azurerm_network_security_group.data.id }

