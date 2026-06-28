# Lab 08 - GitHub Actions CI/CD cho Container Apps

## Mục tiêu

Build, kiểm tra, đóng gói Docker, push ACR và deploy revision mới lên Container Apps bằng GitHub Actions. Azure authentication dùng GitHub OIDC, không dùng long-lived access key.

## Requires / Produces

- Requires: Lab 5 đã apply và service `csnp-platform-wallet-api-service` đang healthy.
- Requires: source WalletMinimal nằm trong `lab-02-acr-container-apps/src/Lab02.WalletMinimal`.
- Produces: GitHub OIDC federated credential, GitHub Actions workflow, ACR image push, and Container Apps revision update.

## Pipeline

```text
Pull request -> restore/build/test
main push -> OIDC -> azure/login -> ACR push (commit SHA) -> az containerapp update -> revision rollout
```

## Security

- Không lưu Azure client secret hoặc access key dài hạn trong GitHub Secrets.
- Federated credential giới hạn đúng repository, branch `main` và GitHub Environment `dev`.
- Image deploy bằng immutable commit SHA, không deploy `latest`.
- Container App config/secrets nên chuyển sang Key Vault hoặc Container Apps secrets, không để plaintext trong workflow.

## Cài đặt

1. Apply Lab 4 và Lab 5 theo `../PRACTICE_SCHEDULE.md`.
2. Apply Terraform trong `terraform/` để tạo identity/federated credential cho GitHub OIDC.
3. Workflow đã có ở `.github/workflows/build-test-deploy.yml`.
4. Tạo GitHub Actions repository variables từ output `terraform output github_actions_variables`.
5. Push lên `main` để workflow build image, push ACR và deploy Container Apps.

## GitHub Actions Variables

Tạo trong GitHub repository: Settings -> Secrets and variables -> Actions -> Variables.

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
AZURE_RESOURCE_GROUP
AZURE_CONTAINER_APP
ACR_LOGIN_SERVER
ACR_REPOSITORY
```

Giá trị cho lab hiện tại:

```text
AZURE_CLIENT_ID=<managed-identity-or-app-client-id>
AZURE_TENANT_ID=<tenant-id>
AZURE_SUBSCRIPTION_ID=<subscription-id>
AZURE_RESOURCE_GROUP=csnp-lab05-rg
AZURE_CONTAINER_APP=csnp-platform-wallet-api
ACR_LOGIN_SERVER=csnpregistry.azurecr.io
ACR_REPOSITORY=csnp-platform-wallet-api
```

## Verify

```bash
az acr repository show-tags \
  --name "${ACR_LOGIN_SERVER%%.azurecr.io}" \
  --repository csnp-platform-wallet-api \
  --orderby time_desc \
  --top 5

az containerapp revision list \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$AZURE_CONTAINER_APP" \
  --query "[?properties.active].{name:name,traffic:properties.trafficWeight,created:properties.createdTime}" \
  --output table
```

## Cleanup

Xóa hoặc disable workflow trước khi destroy Microsoft Entra ID / Azure RBAC role để tránh pipeline chạy lỗi ngoài ý muốn.

Destroy theo thứ tự trong Session 1:

```bash
cd lab-08-cicd/terraform && terraform destroy
cd ../../lab-07-auto-scaling-resilience/terraform && terraform destroy
cd ../../lab-06-observability/terraform && terraform destroy
cd ../../lab-05-terraform-container-apps-platform/terraform && terraform destroy
cd ../../lab-04-terraform-platform-foundation/terraform && terraform destroy
```

## Trạng thái

Configured for monorepo source path `lab-02-acr-container-apps/src/Lab02.WalletMinimal`.

