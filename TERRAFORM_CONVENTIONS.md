# Terraform Conventions for Azure Labs

These conventions apply to every Terraform-based lab in this repository. The
Azure repo must use Azure-native providers, backends, identity, and naming; do
not copy AWS provider/backend examples into Azure labs.

## File responsibilities

| File | Responsibility |
| --- | --- |
| `versions.tf` | Terraform version, required providers, provider configuration |
| `backend.tf` | Remote backend only |
| `variables.tf` | Input variables only |
| `outputs.tf` | Outputs only |
| `main.tf` | Primary resources for small labs |
| `<concern>.tf` | Resources split by concern when `main.tf` becomes difficult to navigate |

Terraform loads all `.tf` files in a directory as one module. Splitting files does not create a module or change resource addresses.

## Provider Pattern

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
}
```

## Backend Pattern

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "csnp-labs-tfstate-rg"
    storage_account_name = "csnplabstfstate"
    container_name       = "tfstate"
    key                  = "azure/lab-NN/terraform.tfstate"
  }
}
```

Exceptions:

- `bootstrap/` uses a local backend because it creates the shared Azure Storage backend.
- A lab may declare additional required providers, such as `random`, `tls`, or `azuread`.
- A multi-region lab may declare Azure provider aliases after the primary provider.
- Every lab gets a unique backend key. Split labs use suffixes, for example
  `azure/lab-12a/terraform.tfstate` and `azure/lab-12b/terraform.tfstate`.
- Do not use AWS S3, DynamoDB locks, AWS profiles, or AWS provider blocks in the
  Azure repo.

## Variables and outputs

- Use multi-line blocks.
- Every variable and output has a description.
- Order variable attributes as `description`, `type`, `default`, `sensitive`, then `validation`.
- Put global inputs first, cross-lab inputs second, and service-specific settings last.
- Mark credentials and other secret inputs as `sensitive = true`.
- Do not commit real `terraform.tfvars`.
- Prefer Azure-native names: `vnet_id`, `subnet_ids`, `nsg_id`,
  `resource_group_name`, `location`, and `subscription_id`.

## Naming and tags

- Resource labels use `snake_case`.
- Azure names use the lab/project prefix already defined by that lab.
- Use `tags` on resources that support them:

```hcl
tags = {
  Project     = "csnp-platform"
  Environment = "lab"
  ManagedBy   = "terraform"
  Lab         = "NN"
}
```

## Formatting and verification

Run before committing:

```powershell
terraform fmt -recursive
terraform validate
```

Changing file layout alone must not rename resource addresses. Any deliberate resource rename requires a `moved` block or explicit state migration.

