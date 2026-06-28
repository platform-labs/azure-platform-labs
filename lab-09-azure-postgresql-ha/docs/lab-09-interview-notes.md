# Lab 09 - Interview Notes

## Azure PostgreSQL HA khác Azure Database for PostgreSQL Flexible Server?

Azure Database for PostgreSQL Flexible Server quản lý một database instance với storage gắn theo instance/Multi-AZ model. Azure PostgreSQL HA tách compute khỏi distributed cluster storage, có writer/reader endpoint và replica promotion nhanh hơn.

## Reader endpoint có load balance mọi query?

Nó phân phối connection mới giữa replicas; không phân tích SQL để tách read/write. Ứng dụng phải dùng đúng connection string và chấp nhận replica lag.

## Multi-AZ instance khác read replica?

Multi-AZ ưu tiên HA/failover. Read replica ưu tiên scale đọc và có thể promotion. Azure PostgreSQL HA replicas vừa phục vụ read vừa là failover target.

## Khi nào không chọn Azure PostgreSQL HA?

Workload nhỏ, cost-sensitive, không cần scale/failover đặc thù hoặc phụ thuộc extension/version PostgreSQL chưa tương thích.

