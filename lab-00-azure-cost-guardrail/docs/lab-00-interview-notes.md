# Lab 00 - Cost Awareness & Control (Interview Notes)

## 1. Tại sao phải setup Budget ngay từ đầu, không chờ sau?

Hầu hết learner mới Azure bị "bill shock" — tạo resource, thực hành một hôm, quên terminate, rồi 3 tháng sau nhận email Azure thông báo $500 invoice.

Azure Monitor Alarms **giúp bạn detect vấn đề trong vòng vài giờ, không phải vài tháng.** Nếu Azure NAT Gateway chạy 7 ngày quên xoá = $7 đốt ngay, bạn alarm sẽ báo trong vòng 1-2 ngày. Nếu không setup → phải chờ billing statement cuối tháng mới biết.

### Keywords

* Cost Awareness
* Alert Latency
* Prevention vs Detection
* Free Tier Exhaustion

---

## 2. Azure Budget vs Azure Monitor Alarms — khác gì?

| Aspect | Azure Budget | Azure Monitor Alarm |
| --- | --- | --- |
| **Cơ chế** | Theo dõi spending dự báo vs thực tế | Trigger khi metric vượt ngưỡng |
| **Cập nhật** | 1 lần/ngày, sau ~22:00 UTC | 1 lần/giờ (hoặc nhanh hơn) |
| **UI** | Dashboard, dễ nhìn, visual | JSON metric, tech hơn |
| **Phù hợp cho** | Tracking monthly spend, forecast | Real-time alert, automation |
| **Email** | Azure SNS, không tùy chỉnh | SNS tùy chỉnh, có thể Lambda trigger |
| **Mục đích** | Planning, "trending"  | Incident response, "stop the bleeding" |

**Thực hành tốt:** Dùng **cả 2**:
* Budget = dashboard tham khảo hàng tuần ("chúng ta đang track đúng không?")
* Azure Monitor Alarm = immediate action ("STOP! chi phí tăng bất thường!")

### Keywords

* Cost Budgets
* Azure Monitor Metrics
* Monitoring
* Alerting
* Real-time vs Daily Reporting

---

## 3. Tại sao EstimatedCharges metric lại cập nhật 1 lần/giờ, không phải real-time?

Azure chỉ tính billing một lần/ngày vào lúc ~22:00 UTC. Để nó update 1 lần/giờ đã là real-time nhất so với Azure Budgets (1 lần/ngày).

Lý do: Azure phải aggregate usage từ mọi region, mọi service, mọi account → tính toán chi phí dựa trên pricing model phức tạp (on-demand, reserved, spot, commitment discounts) → update metric → gửi tới Azure Monitor. **Không thể instant** vì dữ liệu chưa settlement lúc dùng.

Với Container Apps/Lambda (pay-as-you-go), mỗi execution tạo 1 usage record → Azure aggregates hàng giờ → metric update → alarm trigger (delay vài giờ là thường).

### Keywords

* Billing Lag
* Metrics Aggregation
* Usage Collection
* Azure Monitor Data Points

---

## 4. Free Tier coverage như thế nào khi làm labs?

Azure **Free Tier bao gồm**:

| Service | Free Tier Limit |
| --- | --- |
| Azure VM t3.micro | 750 hours/month |
| Azure Database for PostgreSQL | 750 hours/month (1 DB, 20 GB storage) |
| Azure Blob Storage | 5 GB storage + 20k GET + 2k PUT |
| Azure NAT Gateway | ❌ **NOT FREE** — $32/month từ lần đầu tạo |
| Azure Container Apps | ❌ **NOT FREE** — ~$0.04/vCPU-hour |
| ALB | ❌ **NOT FREE** — ~$15/month + LCU charges |
| Azure Monitor | 10 custom metrics free, Alarms free |
| SNS | 100 email notifications free |

**Impact trên Labs:**

* Lab 1: Azure Database for PostgreSQL + Azure VM = free, tuy nhiên **nếu** chạy > 750h (full month) hoặc > 1 DB/instance → charged
* Lab 3 NAT: **First day of NAT = $1.29**, không miễn phí một phút nào
* Lab 5 Container Apps+ALB: **~$50/month nếu chạy full, không free**

### Keywords

* Free Tier Limits
* Always Free vs 12 Months
* Free Tier Tracking
* Post-Free-Tier Costs

---

## 5. Tag strategy — làm sao để cost allocation sau này dễ?

Khi tạo resource, gắn tag ngay:

```hcl
# Example terraform tag
tags = {
  Lab         = "lab-05"
  Environment = "dev"
  Owner       = "csnp-platform"
  Cleanup     = "true"        # nhắc nhở xoá
  Date        = "2026-06-19"
}
```

Sau đó vào **Cost & Usage Reports** → **Group By** → **Tag** (Lab) → xem chi phí chia theo lab.

**Lợi ích:**

* Biết lab nào tốn nhất (ví dụ Lab 5 ecs+alb tốn hơn Lab 1 rds+ec2)
* Tracking ROI của từng giải pháp/project
* Chargeback model nếu có nhiều teams
* Audit trail khi cần refund

Tuy nhiên **tag không thể áp dụng retroactive** — phải tag từ lúc tạo resource.

### Keywords

* Cost Allocation Tags
* Cost Attribution
* Cost Centers
* Resource Grouping
* Chargeback Models

---

## 6. Cleanup workflow — xoá sạch resources mà không ảnh hưởng mỗi cái khác

**Dependency order** (phải xoá theo thứ tự, không xoá ngược):

```
ALB (xoá trước)
  ↑ (phụ thuộc vào)
Container Apps Service (xoá thứ 2)
  ↑
Azure Database for PostgreSQL (xoá thứ 3)
  ↑
Azure NAT Gateway (xoá thứ 4 — ưu tiên, chi phí cao)
  ↑
VNet (xoá thứ 5, cuối cùng)
```

**Nếu xoá sai thứ tự:** ví dụ xoá VNet trước xoá NAT → NAT bị orphan, vẫn tính tiền.

**Best practice:**

```bash
# Terraform: xoá theo dependency
terraform destroy -target=azure_lb.main           # ALB
terraform destroy -target=azure_ecs_service.main  # Container Apps Service
terraform destroy -target=azure_db_instance.main  # Azure Database for PostgreSQL
terraform destroy -target=azure_nat_gateway.main  # NAT
terraform destroy                               # Mọi cái còn lại
```

**Verify sau cleanup:**

* [ ] Vào Billing Console → Costs & Usage → **Last 24 hours** → chi phí phải về 0-1 (chỉ còn Azure Blob Storage storage nếu giữ bucket)
* [ ] Azure VM → Elastic IPs → không có "Associated" IP nào
* [ ] Azure Database for PostgreSQL → no instances (hoặc all stopped)
* [ ] Azure NAT Gateways → 0
* [ ] Budget alert sẽ update hôm sau, tracking cleanup thành công

### Keywords

* Resource Destruction
* Dependency Order
* Orphaned Resources
* Cleanup Verification
* Billing Confirmation

---

## 7. Làm sao phân biệt chi phí tạo ra bởi Lab X và Lab Y khi chạy song song?

Nếu Lab 4 (terraform network) + Lab 5 (terraform ecs) chạy cùng lúc → NAT, ALB, Azure Database for PostgreSQL, Azure Container Apps tất cả chạy → EstimatedCharges = tổng hết.

**Cách phân tách:**

1. **Run Lab 4 alone** → check EstimatedCharges lúc vừa xong Lab 4 (`terraform apply` xong, trước Lab 5)
   * Expected: NAT ~$0.04/day (sau 1-2 ngày = ~$0.08-0.16, LAB 4 only)

2. **Run Lab 5** (keep Lab 4 running) → check EstimatedCharges sau `terraform apply` Lab 5
   * Expected: NAT $0.04 + Container Apps+ALB $0.5-1/day (sau 1-2 ngày = tổng ~$1.50)
   * Suy ra: Lab 5 added = $1.50 - $0.16 = ~$1.34

Tuy nhiên **cách chính xác nhất** là:
* Lab 4 → cleanup ngay → EstimatedCharges xem giảm bao nhiêu = cost of Lab 4
* Lab 5 → cleanup ngay → EstimatedCharges xem giảm bao nhiêu = cost of Lab 5

### Keywords

* Cost Attribution
* Incremental Costing
* Isolation Testing
* Resource-level Pricing

---

## 8. Reserved Instances hay Savings Plans có cần dùng cho labs?

**Không, đừng dùng cho labs.**

| Model | Best For | Cost |
| --- | --- | --- |
| On-Demand | Temporary, testing, labs | Full price ($0.023/h for t3.small) |
| Reserved Instances (1 year) | Stable, production | ~$180/year (55% discount) |
| Savings Plans | Flexible compute, prod | ~$200/year (50% discount) |
| Spot Instances | Batch jobs, interruption-tolerant | ~$0.007/h (70% discount) |

**Vì sao không RI/Savings cho lab?**
* Upfront payment (1 year commitment) không có ý nghĩa với lab tạm thời
* Chỉ cần flexibility — terminate ngay khi xong, không cần optimize recurring cost
* Break-even point: ~5 tháng on-demand = RI cost (không đáng nếu chỉ dùng 2-3 tháng)

**Có nên dùng Spot cho lab?** Có, nếu acceptance interruption (Azure VM có thể bị terminate đột ngột nếu Azure cần capacity). Cho test/dev có thể chấp nhận, tiết kiệm 70%.

### Keywords

* On-Demand Pricing
* Reserved Instances
* Savings Plans
* Spot Instances
* Cost Optimization
* Break-even Analysis

---

## 9. Tại sao Azure Monitor Alarm alert không trigger ngay khi EstimatedCharges update?

EstimatedCharges metric có **"evaluation period" = 1 hour, "datapoints to alarm" = 1** — nghĩa là:

* 00:00 - Azure Monitor kiểm tra EstimatedCharges
* Nếu value > threshold → alarm state = ALARM (nhưng notification có delay)
* Notification gửi qua SNS → SNS gửi email → email đến inbox (tổng ~5-15 phút delay)

Delay chủ yếu do:
1. Azure aggregates usage → update metric → 5 phút
2. Azure Monitor evaluates → 1 hour (nếu period = 1h)
3. SNS sends notification → 1-5 phút
4. Email provider queue → 1-10 phút

**Cách giảm delay:**

* Set **Period = 1 minute** (thay vì 1 hour) → trigger nhanh hơn
* Nhưng metric data có delay 1 hour (Azure chỉ update 1 lần/hour) → setting này vô ích
* **Thực tế:** nhanh nhất cũng ~1 hour từ lúc charge phát sinh đến lúc alarm trigger

**Giải pháp tốt hơn:** Dùng **Azure Cost Anomaly Detection** (machine learning detect bất thường, trigger trong vòng vài phút).

### Keywords

* Evaluation Periods
* Datapoints to Alarm
* Alert Latency
* Azure Monitor Behavior
* Anomaly Detection

---

## 10. Nên cleanup theo schedule (hàng tuần) hay on-demand (sau mỗi lab)?

**Best practice: Hybrid**

| Khi nào | Action | Tần suất |
| --- | --- | --- |
| Lab xong | Cleanup **on-demand** ngay | Sau mỗi lab (1-2 ngày) |
| Theo schedule | Audit billing, kiểm tra orphaned resources | Hàng tuần (Thứ 6 sáng) |
| On-call | Respond to budget alerts | Real-time |

**Lý do:**
* On-demand cleanup = ngay lập tức tiết kiệm ($32 NAT = xoá trong 1 ngày thay vì 1 tuần = tiết kiệm $4)
* Weekly audit = catch forgotten resources, orphaned EIP, old snapshots
* On-call = react nếu cost spike bất thường (ví dụ data transfer out, misconfigured scaling)

**Checklist hàng tuần:**

```
[ ] Kiểm tra EstimatedCharges trend
[ ] Xem dịch vụ nào mới appear (ví dụ Azure Front Door/CDN, DataTransfer)
[ ] Verify mọi Azure VM đều có Owner tag + Cleanup date
[ ] Audit Azure NAT Gateways → xoá nếu không dùng
[ ] Kiểm tra Azure Database for PostgreSQL snapshots (often forgotten, tính tiền storage)
```

### Keywords

* Operational Excellence
* Cost Optimization
* Regular Reviews
* Reactive vs Proactive
* Best Practices

