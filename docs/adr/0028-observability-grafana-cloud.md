# AS-0028: Observability on Grafana Cloud free tier

## Status

Accepted. (Revised 2026-05-15 — inverts an earlier "CloudWatch-native v1"
draft.)

## Context

Two postures were considered for v1 observability:

1. **CloudWatch-native** — Fluent Bit + Container Insights + CloudWatch
   dashboards/alarms. AWS-native, minimal moving parts. Prometheus / Loki /
   OpenTelemetry / Tempo would be a later "aspiration".
2. **Open-observability** — OpenTelemetry instrumentation + Grafana Alloy →
   Grafana Cloud (Mimir / Loki / Tempo / Pyroscope) from day one.

`CloudWatch + X-Ray` is *not* feature-parity with the Grafana stack — it
predates the OpenTelemetry standardisation and has a narrower surface (no
continuous profiling, weak cross-signal correlation).

## Decision

Start at posture 2. The app emits OpenTelemetry (metrics + traces) and Pyroscope
(profiles) to a node-local Grafana Alloy DaemonSet, which also scrapes
node-exporter / kube-state-metrics / cAdvisor and tails pod logs, and forwards
everything to Grafana Cloud. Dashboards and alert rules are declared via the
`grafana/grafana` Terraform provider — no manual UI edits.

CloudWatch is retained only as a side-effect surface: EKS control-plane logs and
ALB access logs, for audit/forensics, never dashboarded.

## Consequences

- **Conversion-cost arbitrage** — building CloudWatch-native first, then
  migrating, would write the observability layer twice. Starting at the target
  posture avoids a throwaway implementation and a migration runbook.
- **Continuous profiling for free** — Pyroscope on the GC free tier; AWS has no
  OpenTelemetry-native equivalent.
- **Unified pane** — PromQL + LogQL + TraceQL + profiles in one Grafana, with
  trace↔metric exemplars.
- **Trade-off** — an external SaaS dependency, and a hard reliance on the GC
  free-tier limits (10k series / 50 GB per signal / 14-day retention; far above
  this workload's needs). The AMP + AMG migration path keeps Alloy and the OTel
  SDK unchanged — only `remote_write` URLs flip. Documented in
  `docs/tradeoffs.md`.
- The DR drill gains a visible signal: a Grafana dashboard shows metrics drop,
  flatline, and recover as the region is destroyed and rebuilt.
