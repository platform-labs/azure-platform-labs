variable "location" {
  type    = string
  default = "eastus"
}
variable "resource_group_name" {
  type    = string
  default = "csnp-labs-tfstate-rg"
}
variable "storage_account_name" {
  type    = string
  default = "csnplabstfstate"
}
variable "container_name" {
  type    = string
  default = "tfstate"
}

