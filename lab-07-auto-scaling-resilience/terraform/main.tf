resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-rg"
  location = var.location
  tags     = var.tags
}

resource "azurerm_container_app" "scaled_example" {
  name                         = "${var.project_name}-scaled-api"
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  template {
    min_replicas = 1
    max_replicas = 5
    http_scale_rule {
      name                = "http-concurrency"
      concurrent_requests = "50"
    }
    container {
      name   = "wallet-api"
      image  = var.container_image
      cpu    = 0.5
      memory = "1Gi"
    }
  }
}


