# Azure Labs Bootstrap Setup Guide

This bootstrap directory creates the shared Azure remote-state infrastructure
used by Terraform-based labs from Lab 01 through Lab 20:

- Azure Resource Group for Terraform state.
- Azure Storage Account for Terraform state.
- Private Blob container named `tfstate`.
- Azure Blob lease locking through the `azurerm` backend.

The storage account is dedicated to `azure-platform-labs`. Do not reuse a
production backend or a state key from another environment.

## Why Bootstrap Uses Local State

Bootstrap creates the Storage Account and Blob container used by the other labs,
so its first apply cannot depend on that remote backend. Bootstrap is the only
intentional local backend.

Keep and back up:

```text
bootstrap/terraform.tfstate
```

The explicit local backend lives in:

```text
bootstrap/backend.tf
```

## Prerequisites

- Azure CLI logged in to the correct subscription.
- Terraform >= 1.7.0.

Check context before applying:

```bash
az account show --output table
terraform version
```

## Setup

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

Verify outputs:

```bash
terraform output resource_group_name
terraform output storage_account_name
terraform output container_name
```

## Backend Convention

Every Terraform-based lab uses the same Azure Storage backend with a unique
state key.

Canonical `backend.tf` pattern:

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

Split labs must use split keys:

```text
azure/lab-12a/terraform.tfstate
azure/lab-12b/terraform.tfstate
```

## State Keys

```text
Lab-01  azure/lab-01/terraform.tfstate
Lab-02  azure/lab-02/terraform.tfstate
Lab-04  azure/lab-04/terraform.tfstate
Lab-05  azure/lab-05/terraform.tfstate
Lab-06  azure/lab-06/terraform.tfstate
Lab-07  azure/lab-07/terraform.tfstate
Lab-08  azure/lab-08/terraform.tfstate
Lab-09  azure/lab-09/terraform.tfstate
Lab-10  azure/lab-10/terraform.tfstate
Lab-11  azure/lab-11/terraform.tfstate
Lab-12A azure/lab-12a/terraform.tfstate
Lab-12B azure/lab-12b/terraform.tfstate
Lab-13  azure/lab-13/terraform.tfstate
Lab-14  azure/lab-14/terraform.tfstate
Lab-15  azure/lab-15/terraform.tfstate
Lab-17  azure/lab-17/terraform.tfstate
Lab-20  azure/lab-20/terraform.tfstate
```

Labs 00, 03A, 03B, 9.5, 16, 18, and 19 have no Terraform state in this repo
unless a future change adds Terraform configuration to them.

## Initialize a Lab

```bash
cd ../lab-XX-*/terraform
terraform init
terraform plan
terraform apply
```

If a lab already has a real local `terraform.tfstate`, migrate it explicitly:

```bash
cp terraform.tfstate terraform.tfstate.pre-azurerm-migration.bak
terraform init -migrate-state
terraform state list
terraform plan
```

Do not use `terraform init -reconfigure` when preserving an existing local
state. `-reconfigure` can make Terraform start against an empty remote state
instead of copying the old state.

## Cleanup

Destroy bootstrap only after every lab has been destroyed and no state files are
needed:

```bash
terraform destroy
```

Do not destroy bootstrap while any lab state remains in the Blob container.
