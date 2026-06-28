resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-rg"
  location = var.location
  tags     = var.tags
}

resource "azurerm_eventhub_namespace" "main" {
  name                = "${var.project_name}-eh"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  capacity            = 1
}

resource "azurerm_eventhub" "stream" {
  name              = "wallet-events"
  namespace_id      = azurerm_eventhub_namespace.main.id
  partition_count   = 2
  message_retention = 1
}


