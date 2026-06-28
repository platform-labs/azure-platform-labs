#!/bin/bash
set -euo pipefail

echo "======================================"
echo "Azure LAB COST / CLEANUP CHECK"
echo "======================================"
echo

echo "Current subscription:"
az account show --query "{name:name, id:id}" --output table

echo
echo "Budgets:"
az consumption budget list --output table || true

echo
echo "Lab-tagged resources:"
az resource list --tag Environment=lab --query "[].{Name:name, Type:type, RG:resourceGroup, Location:location}" --output table

echo
echo "Container Apps:"
az containerapp list --query "[].{Name:name, RG:resourceGroup, Env:properties.environmentId}" --output table

echo
echo "Azure Database for PostgreSQL Flexible Servers:"
az postgres flexible-server list --query "[].{Name:name, RG:resourceGroup, State:state, SKU:sku.name}" --output table

echo
echo "Storage Accounts:"
az storage account list --query "[].{Name:name, RG:resourceGroup, SKU:sku.name}" --output table

echo
echo "NAT Gateways:"
az network nat gateway list --query "[].{Name:name, RG:resourceGroup, Location:location}" --output table

