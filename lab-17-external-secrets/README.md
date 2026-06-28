# Lab 17 - External Secrets Operator

## Mục tiêu

Đồng bộ secret từ Azure Key Vault vào Kubernetes bằng External Secrets Operator (ESO), sử dụng IRSA thay vì static Azure keys.

## Requires / Produces

- Requires: Lab 16, AKS OIDC provider và secret Lab 6.
- Produces: least-privilege Microsoft Entra ID / Azure RBAC role, ClusterSecretStore và ExternalSecret.

## Security boundary

ESO tạo Kubernetes Secret; dữ liệu vẫn tồn tại trong etcd. AKS envelope encryption, RBAC, audit và namespace boundary vẫn bắt buộc.

## Cleanup

Xóa ExternalSecret/SecretStore trước Microsoft Entra ID / Azure RBAC role. Không xóa source secret nếu còn consumer khác.

## Trạng thái

Code-ready, chưa apply.

