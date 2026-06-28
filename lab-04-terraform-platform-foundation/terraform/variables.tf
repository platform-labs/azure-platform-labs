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

variable "vnet_cidr" {
  type    = string
  default = "10.10.0.0/16"
}
variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.1.0/24", "10.10.2.0/24"]
}
variable "private_app_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.11.0/24", "10.10.12.0/24"]
}
variable "private_data_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.21.0/24", "10.10.22.0/24"]
}

