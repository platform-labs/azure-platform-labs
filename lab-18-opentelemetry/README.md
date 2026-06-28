# Lab 18 - OpenTelemetry + Azure Application Insights

## Mục tiêu

Thu trace chuẩn OpenTelemetry từ Wallet API qua OpenTelemetry Collector Collector và export sang Azure Application Insights.

## Requires / Produces

- Requires: Lab 16; AKS workload.
- Produces: OpenTelemetry Collector collector config, workload instrumentation patch và Microsoft Entra ID / Azure RBAC policy boundary.

## Flow

```text
Wallet API (OTLP) -> OpenTelemetry Collector Collector -> Azure Application Insights
```

## Guardrail

Sampling mặc định thấp để kiểm soát cost và PII. Không ghi request/response body hoặc secret vào span attributes.

## Trạng thái

Code-ready, chưa apply.

