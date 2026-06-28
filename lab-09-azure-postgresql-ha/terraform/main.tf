resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-rg"
  location = var.location
  tags     = var.tags
}

resource "azurerm_postgresql_flexible_server" "primary" {
  name                   = "${var.project_name}-pg-primary"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  version                = "16"
  administrator_login    = var.db_admin
  administrator_password = var.db_password
  sku_name               = "GP_Standard_D2s_v3"
  storage_mb             = 32768
  zone                   = "1"
  high_availability {
    mode                      = "ZoneRedundant"
    standby_availability_zone = "2"
  }
}


