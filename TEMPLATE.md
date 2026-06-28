# Lab NN - <Tên Lab>

## Mục tiêu

Sau lab này cần hiểu được:

* ...
* ...

## Prerequisites

* ...
* Azure Region: **eastus** (đổi nếu khác)

## Architecture

```text
TODO - vẽ sơ đồ ASCII flow của lab này
```

## Azure Services

| Service | Vai trò |
| ------- | ------- |
| ... | ... |

## Estimated Cost

| Resource | Chi phí ước tính |
| -------- | ----------------- |
| ... | ... |

> Set Azure Budget alert nếu lab có resource tốn tiền theo giờ (ALB, Azure NAT Gateway, Azure Database for PostgreSQL multi-AZ...).

## Region

`eastus` (hoặc ghi region thực tế đã dùng, để lần sau không tạo resource rải rác ở region khác).

## Cleanup

* [ ] `terraform destroy` (nếu lab dùng Terraform)
* [ ] Xóa thủ công các resource tạo qua Console (nếu có)
* [ ] Kiểm tra EBS volume / Elastic IP còn sót lại không
* [ ] Verify trong Azure Cost Explorer không còn resource đang chạy

## Lessons Learned

* ...

## Deliberate practice loop

1. **Mental model:** ...
2. **Console discovery:** ...
3. **Implementation:** ...
4. **CLI verification:** ...
5. **Failure drill:** ...
6. **Rebuild without guide:** ...
7. **Cleanup/cost audit:** ...
8. **Interview recap:** ...

Theo dõi lượt luyện bằng [`DELIBERATE_PRACTICE.md`](./DELIBERATE_PRACTICE.md).

---

## Cấu trúc thư mục cho lab mới

```text
lab-NN-ten-lab/
├── README.md              <- copy từ template này, điền nội dung
├── docs/
│   ├── lab-NN-hands-on.md
│   └── lab-NN-interview-notes.md   (optional)
├── src/
│   └── LabNN.TenApp/       (nếu lab có code)
├── terraform/
│   ├── .gitignore
│   ├── backend.tf          (Azure Blob Storage backend, key riêng cho từng lab)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
└── screenshots/
```

