resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-rg"
  location = var.location
  tags     = var.tags
}

resource "azurerm_servicebus_namespace" "main" {
  name                = "${var.project_name}-sb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
}

resource "azurerm_servicebus_queue" "wallet_commands" {
  name         = "wallet-commands"
  namespace_id = azurerm_servicebus_namespace.main.id
}


