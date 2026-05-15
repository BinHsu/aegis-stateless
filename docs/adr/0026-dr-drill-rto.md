# AS-0026: DR drill — a measured RTO, not a round number

## Status

Accepted.

## Context

A DR story is only credible if its recovery time is *measured* and *attributed*.
"~15 minutes" is marketing — it invites the question "15 minutes of what?".

## Decision

The drill is a defined cycle: `make destroy-region REGION=<r>` tears down one
region's `regional` stack; `make regional-one REGION=<r>` rebuilds it; ArgoCD
reconciles the workload from git. `platform` (Route 53, ECR images, Grafana
dashboards) is untouched.

The recovery time is stated as **20-30 minutes**, broken down by what dominates:

| Phase | Time |
|---|---|
| EKS managed control plane provisioning | ~15 min |
| Managed node group ready + addons (CNI, CoreDNS, kube-proxy) | ~5 min |
| ALB target group healthy + DNS propagation | ~1-3 min |
| ArgoCD sync of the workload from git | ~30 s |

## Consequences

- The number is defensible: a reviewer sees the EKS control plane is the
  bottleneck, and that the GitOps layer (ArgoCD) is negligible.
- Other failure modes have their own, smaller RTOs, documented separately: a
  dead pod (Kubernetes reconciles in seconds), a dead node (ASG replaces in
  ~2-5 min), a region failover (not implemented; would be Route 53 TTL +
  health-check interval ≈ 1-2 min).
- The drill proves the real claim: Terraform state + git are the source of
  truth, and the workload converges from zero without manual `kubectl`.
