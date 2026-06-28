resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-rg"
  location = var.location
  tags     = var.tags
}

resource "azurerm_monitor_action_group" "alerts" {
  name                = "${var.project_name}-alerts"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "lab06"
  email_receiver {
    name          = "primary"
    email_address = var.alarm_email
  }
}

resource "azurerm_application_insights" "main" {
  name                = "${var.project_name}-appi"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"
}

resource "azurerm_key_vault" "main" {
  name                       = replace("${var.project_name}-kv", "-", "")
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
}


