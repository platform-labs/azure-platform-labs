resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-rg"
  location = var.location
  tags     = var.tags
}

resource "azurerm_key_vault" "main" {
  name                       = replace("${var.project_name}-kv", "-", "")
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
}

resource "azurerm_user_assigned_identity" "external_secrets" {
  name                = "${var.project_name}-eso"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}


