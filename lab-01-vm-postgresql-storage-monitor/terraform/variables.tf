variable "project_name" {
  type    = string
  default = "csnp-lab"
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "tags" {
  type = map(string)
  default = {
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}
variable "ssh_public_key" {
  type = string
}
variable "db_admin" {
  type    = string
  default = "walletadmin"
}
variable "db_password" {
  type      = string
  sensitive = true
}

