# ADR-05: Disaster recovery

## Status

Accepted.

## Context

A DR story is credible only if its recovery time is *measured* and *attributed*.
"~15 minutes" is marketing — it invites "15 minutes of what?". And the recovery
target depends on what there is to recover.

## Decision

**RPO is not applicable — the greeter is stateless by design.** It holds no
persistent data; there is nothing to lose and nothing to restore. The metric a
stateful system fights for is trivially satisfied here, and that is the point
of the stateless architecture.

**The measured number is a *cold-rebuild* RTO** — the time to reconstruct the
region from zero (Terraform state + git), with no warm standby. Naming it
matters: a *failover* RTO and a *cold-rebuild* RTO are different numbers for
different failures. It is **20-30 minutes**, broken down by what dominates:

| Phase | Time |
|---|---|
| EKS managed control-plane provisioning | ~15 min |
| Managed node group ready + addons (CNI, CoreDNS, kube-proxy) | ~5 min |
| ALB target group healthy + DNS propagation | ~1-3 min |
| ArgoCD sync of the workload from git | ~30 s |

**The drill is a defined cycle.** `make destroy-region` tears down one region's
`regional` stack; `make regional-one` rebuilds it; ArgoCD reconciles the
workload from git. `platform` (Route 53, ECR images, Grafana dashboards) is
untouched. `scripts/dr/dr-drill.sh` sequences and times the phases and writes a
report to `docs/evidence/`. The full failure-mode matrix and procedure are in
[`dr-plan.md`](../dr-plan.md).

## Consequences

- The RTO number is defensible: a reviewer sees the EKS control plane is the
  bottleneck and the GitOps layer (ArgoCD) is negligible — ~15 of the ~25
  minutes is a fixed AWS cost this repo cannot optimise.
- Cheaper failures recover faster and more automatically: a dead pod
  (Kubernetes, seconds), a dead node (managed node group, ~2-5 min), an
  impaired AZ (multi-AZ replicas absorb it). Only region loss needs the
  IaC + GitOps recovery path, so that is the drill scenario.
- The cold-rebuild RTO is the number that matters most: it is the recovery
  path for the failure class redundancy *cannot* cover — operator error, or a
  bad change GitOps faithfully propagates to every replica. Multi-region
  failover (designed via Pattern X, not deployed) is a different, smaller
  number (~1-2 min) for a narrower failure: a region dying. The drill measures
  reconstructability, not redundancy.
- The drill proves the real claim: Terraform state + git are the source of
  truth; the workload converges from zero with no manual `kubectl`.
- Evidence is committed to git, not left in a live environment — the cluster is
  torn down after the demo and Grafana Cloud retains data only ~14 days, so a
  live link would be dead by the time a reviewer opens the submission.
