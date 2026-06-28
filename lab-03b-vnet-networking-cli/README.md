# Lab 03B - VNet Networking (CLI)

## Mục tiêu

Phần tiếp theo của Lab 3A — chuyển từ **Azure Console** sang **Azure CLI** để hiểu Console thực chất gọi những API Azure nào, và quen cú pháp CLI trước khi viết Terraform ở Lab 4.

Sau lab này cần hiểu được:

* Azure CLI command structure: `aws service action --parameters`
* Resource ID (VNet ID, Subnet ID, Route Table ID) — CLI không tự nhớ context, phải truyền thủ công
* API dependency — khi xoá VNet, phải disassociate Route Table trước, xoá Subnet, rồi mới xoá VNet
* CLI output format (JSON) — từ dó extract ID dùng cho lệnh tiếp theo
* So sánh logic Console ≡ CLI: Console che giấu dependency, CLI phơi bày rõ ràng

## Prerequisites

* Đã hoàn thành **Lab 3A** (hiểu rõ VNet/Subnet/Route Table/NAT concept bằng tay Console)
* Azure CLI **phiên bản >= 2.0** cài sẵn ([download](https://aws.amazon.com/cli/))
* Azure CLI đã configure: `aws configure` hoặc Microsoft Entra ID / Azure RBAC Identity Center SSO
* Azure Region: **eastus**
* Quyền Azure VM: CreateVpc, CreateSubnet, CreateRouteTable, AssociateRouteTable, DeleteVpc (...)

> **IMPORTANT:** Lab 3B tạo VNet **test riêng** (`10.20.0.0/16` - CLI Learning Sandbox) — **KHÔNG can thiệp tới VNet chính** (`10.10.0.0/16` ở Lab 3A). Sau lab xong, xoá VNet test ngay.

## Architecture

Lab 3B không build full network như Lab 3A. Chỉ tạo **minimal resources** để minh hoạ API:

```text
VNet Test (10.20.0.0/16)
    ↓
Subnet (10.20.1.0/24)
    ↓
Route Table + Association
    ↓
(sau đó xoá toàn bộ để học cleanup)
```

## Azure Services

| Service | Vai trò |
| ------- | ------- |
| Azure VM (VNet API) | `create-vpc`, `create-subnet`, `create-route-table`, `associate-route-table`, `delete-*` |
| Azure CLI | Client để gọi API thay vì qua Console |
| Microsoft Entra ID / Azure RBAC | Permission để thực thi Azure VM API (quyền `ec2:*` hoặc specific action) |

## Chi phí

Tạo VNet, Subnet, Route Table — **free** (không charge khi không có resource chạy trong đó). **Chi phí chỉ phát sinh khi thêm resources như Azure NAT Gateway, Azure VM, Azure Database for PostgreSQL.**

## Region

`eastus`

## Lessons Learned (Preview)

* Console và CLI gọi **cùng một API Azure** — khác biệt là Console tự lưu context, CLI để bạn quản lý thủ công
* **Dependency Management**: Thứ tự xoá ngược với thứ tự tạo — nếu quên, Azure báo lỗi "VNet has dependencies"
* CLI output là JSON — dễ dàng parse với `--query` để extract ID cho lệnh tiếp theo
* **Transition Point**: Sau Lab 3B (CLI), bạn sẽ thấy tại sao Lab 4 (Terraform) tự động hoá bước này — Terraform tự tính dependency graph, tự quyết định thứ tự tạo/xoá

## Nội dung Chi tiết

| File | Mục đích |
| --- | --- |
| [lab-03b-hands-on.md](./docs/lab-03b-hands-on.md) | Step-by-step: tạo VNet test → verify → cleanup bằng CLI |
| [lab-03b-interview-notes.md](./docs/lab-03b-interview-notes.md) | Q&A về CLI, API, dependency management |
| [lab-03b-verification.md](./docs/lab-03b-verification.md) | Checklist verify sau mỗi step |

## Chuẩn bị

* Mở terminal (PowerShell / Bash / WSL2)
* Chạy `aws --version` → verify Azure CLI 2.x cài sẵn
* Chạy `aws sts get-caller-identity` → verify Azure CLI configure đúng
* Sẵn sàng lấy từng VNet/Subnet ID từ output và lưu vào `export` variable

## Trạng thái

Đây là lab **hands-on** — yêu cầu chạy terminal commands. Ước tính 20-30 phút để xong (tạo + cleanup).

