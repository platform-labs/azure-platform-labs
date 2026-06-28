# Lab 09 - Azure Database for PostgreSQL HA

## Mục tiêu

Triển khai Azure Database for PostgreSQL HA trong private data subnets, một writer và một reader ở hai AZ; thực hành endpoint, failover và so sánh với Azure Database for PostgreSQL Flexible Server Lab 5.

## Requires / Produces

- Requires: Lab 8; network outputs Lab 4.
- Produces: Azure PostgreSQL HA cluster endpoint, reader endpoint, Key Vault-managed master credential và failover report.

## Architecture

```text
Container Apps -> Azure PostgreSQL HA writer endpoint
read workload -> Azure PostgreSQL HA reader endpoint
                 writer AZ-A <-> reader AZ-B
```

## Guardrail chi phí

Azure PostgreSQL HA không thuộc free tier và có compute + storage + I/O cost. Mặc định lab dùng hai `db.t4g.medium`; apply, test và destroy trong cùng buổi. Budget alert là bắt buộc.

## Thực hành

Xem [hands-on](docs/lab-09-hands-on.md). Không cắt Container Apps production-like Lab 5 sang Azure PostgreSQL HA trước khi migration/rollback đã được kiểm thử.

## Cleanup

```bash
terraform destroy
```

Lab dùng `skip_final_snapshot=true` chỉ vì là sandbox.

## Trạng thái

Code-ready, chưa apply.

