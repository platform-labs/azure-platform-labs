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

variable "github_repository" {
  type = string
}

