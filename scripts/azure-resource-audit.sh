#!/bin/bash
set -euo pipefail

echo "===== RESOURCE GROUPS ====="
az group list --query "[].{Name:name, Location:location}" --output table

echo
echo "===== CONTAINER APPS ====="
az containerapp list --query "[].{Name:name, RG:resourceGroup, FQDN:properties.configuration.ingress.fqdn}" --output table

echo
echo "===== ACR REGISTRIES ====="
az acr list --query "[].{Name:name, RG:resourceGroup, LoginServer:loginServer, SKU:sku.name}" --output table

echo
echo "===== AKS CLUSTERS ====="
az aks list --query "[].{Name:name, RG:resourceGroup, Version:kubernetesVersion}" --output table

echo
echo "===== POSTGRESQL FLEXIBLE SERVERS ====="
az postgres flexible-server list --query "[].{Name:name, RG:resourceGroup, State:state, Version:version}" --output table

echo
echo "===== STORAGE ACCOUNTS ====="
az storage account list --query "[].{Name:name, RG:resourceGroup, SKU:sku.name}" --output table

echo
echo "===== KEY VAULTS ====="
az keyvault list --query "[].{Name:name, RG:resourceGroup, Location:location}" --output table

echo
echo "===== VNETS ====="
az network vnet list --query "[].{Name:name, RG:resourceGroup, CIDR:addressSpace.addressPrefixes}" --output table

echo
echo "===== PUBLIC IPS ====="
az network public-ip list --query "[].{Name:name, RG:resourceGroup, IP:ipAddress}" --output table

