# DR drill evidence

Artefacts from an actual DR drill run. A drill is a claim until it is
evidenced; this directory holds the proof, committed into git so a reviewer
sees it without a live environment.

## What lands here

| Artefact | Produced by | Backs the claim |
|---|---|---|
| `DR_REPORT.md` | `scripts/dr/dr-drill.sh` | The region rebuilt from IaC + git; phase timeline + measured RTO. |
| `dr-drill-<timestamp>.log` | `scripts/dr/dr-drill.sh` | Full phase-by-phase CLI output — `terraform`, `kubectl`, timings. |
| `grafana-dr-curve.png` | operator, captured manually during the drill window | The observability signal: request rate / latency drop at teardown, flat through the rebuild, recover at reconverge. |

## Why screenshots, not links

The Grafana evidence is a committed PNG, not a live dashboard link. The drill
tears the cluster down; after the demo the whole stack is destroyed to stop
AWS billing, and Grafana Cloud's free tier retains metric data only ~14 days.
A live link would be dead by the time a reviewer opens the submission — so the
proof is captured in-window and committed here.

## Reproducing

```bash
scripts/dr/dr-drill.sh eu-central-1
```

See [`../dr-plan.md`](../dr-plan.md) for the plan, the failure-mode matrix, and
the RTO/RPO targets each artefact is measured against.
