terraform {
  # Bootstrap is the only intentional local backend. It creates the Azure
  # Storage Account and container used by every Terraform-based lab.
  backend "local" {
    path = "terraform.tfstate"
  }
}
