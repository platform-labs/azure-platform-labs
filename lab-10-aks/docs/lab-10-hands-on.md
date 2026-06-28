# Lab 10 - Hands-on

## Deliberate practice loop

1. **Mental model:** map Container Apps concepts sang cluster/node/pod/deployment/service/ingress/HPA và vẽ Microsoft Entra ID / Azure RBAC/network paths.
2. **Console discovery:** xem AKS control plane, node group, add-ons và workload sau Terraform/kubectl apply.
3. **Implementation:** apply cluster, cài controllers rồi deploy app/HPA.
4. **CLI verification:** kết hợp `az aks` và `kubectl get/describe/events`.
5. **Failure drill:** bad readiness probe, crash loop hoặc pod Pending; chẩn đoán đúng layer trước khi sửa.
6. **Rebuild without guide:** từ cluster output, tự đưa workload tới ingress healthy.
7. **Cleanup/cost audit:** xóa Ingress/LoadBalancer trước node pool/cluster; kiểm tra Load Balancer, Public IP và node resource group.
8. **Interview recap:** giải thích control plane, data plane, HPA và node capacity scaling.

Theo dõi lượt luyện: [`../../DELIBERATE_PRACTICE.md`](../../DELIBERATE_PRACTICE.md).

## 1. Apply cluster

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
az aks get-credentials \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name csnp-lab10 \
  --overwrite-existing
kubectl get nodes -o wide
```

Giới hạn `public_access_cidrs` thành public IP `/32` của máy admin; không để `0.0.0.0/0`.

## 2. Cài metrics-server và ingress controller

Dùng AKS add-on/Helm theo tài liệu Azure hiện hành. Controller/workload identity cần Microsoft Entra Workload ID hoặc Managed Identity scoped phù hợp.

## 3. Deploy app

Sửa image trong `kubernetes/deployment.yaml`, sau đó:

```bash
kubectl apply -f kubernetes/
kubectl rollout status deployment/wallet-api
kubectl get deploy,pod,svc,ingress,hpa
```

## 4. Test HPA

Tạo traffic ngắn, quan sát `kubectl get hpa -w`. HPA cần resource requests và metrics-server.

## 5. Cleanup đúng thứ tự

```bash
kubectl delete -f kubernetes/
terraform destroy
```

