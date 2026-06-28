terraform {
  backend "azurerm" {
    resource_group_name  = "csnp-labs-tfstate-rg"
    storage_account_name = "csnplabstfstate"
    container_name       = "tfstate"
    key                  = "azure/lab-07/terraform.tfstate"
  }
}

