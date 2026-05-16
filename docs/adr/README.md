# Architecture Decision Records

Each ADR captures one significant decision: the context that forced it, the
decision taken, and the consequences accepted. Format follows Michael Nygard's
template (Status / Context / Decision / Consequences).

IDs use the `AS-` prefix (aegis-stateless) to distinguish them from the sibling
app repo's `AG-` records.

## The records

| ADR | Decision | What you'll find |
|---|---|---|
| [AS-0000](0000-record-architecture-decisions.md) | Record architecture decisions | Why this repo keeps ADRs; the template. |
| [AS-0001](0001-project-local-toolchain.md) | Project-local Terraform toolchain | Pinned tool versions into `./bin/`; host-isolation discipline; reproducible for a forker. |
| [AS-0013](0013-single-region-applied-multi-region-designed.md) | Single region applied, multi-region designed | The honest failure mode — one region is a SPOF — and why that is the right cost-bounded choice. |
| [AS-0015](0015-per-cluster-argocd.md) | Per-cluster ArgoCD over hub-spoke | Each cluster runs its own ArgoCD; no GitOps-layer single point of failure. |
| [AS-0019](0019-ci-driven-apply.md) | CI-driven apply with a branch-protection gate | GitHub Actions as the canonical apply path; two OIDC roles split trust (read-only plan vs apply-on-main). |
| [AS-0020](0020-pattern-x-external-orchestration.md) | Pattern X — multi-region as data | The signature design: region topology is data, not code; adding a region is a one-line change. |
| [AS-0021](0021-three-env-lifecycle-split.md) | Three-environment lifecycle split | bootstrap / platform / regional — separated by how fast each changes and by DR blast radius. |
| [AS-0026](0026-dr-drill-rto.md) | DR drill — measured RTO, not a round number | The 20–30 min RTO broken down by phase; why "~15 min" would be marketing. |
| [AS-0028](0028-observability-grafana-cloud.md) | Observability on Grafana Cloud free tier | OpenTelemetry + Alloy → Grafana Cloud; why the open stack from day one over CloudWatch-native. |
| [AS-0032](0032-s3-native-state-locking.md) | S3 native state locking over DynamoDB | `use_lockfile` (TF ≥ 1.11) replaces the DynamoDB lock table — one less resource. |

## Reading order by audience

**I want the architecture in 10 minutes** — the [README architecture
section](../../README.md#architecture), then whichever ADR your question lands on.

**Senior platform reviewer** — the order that builds the argument:
AS-0020 (Pattern X — the signature design) → AS-0021 (the env split that makes
it safe) → AS-0015 (per-cluster ArgoCD) → AS-0019 (CI-driven apply) → AS-0013
(the honest single-region trade-off) → AS-0026 (DR drill).

**Reliability / DR reviewer** — AS-0026 (DR RTO) → AS-0013 (single-region
failure mode) → AS-0021 (lifecycle split = DR blast radius) → AS-0015 (ArgoCD
SPOF elimination).

**Security / supply-chain reviewer** — AS-0019 (CI trust split, branch
protection, scoped OIDC roles) → AS-0001 (pinned toolchain, host isolation) →
AS-0032 (state locking).

**Observability reviewer** — AS-0028, then the observability section of
[`docs/tradeoffs.md`](../tradeoffs.md).

## Smaller decisions

Deployment over StatefulSet, EKS managed control plane, ALB Ingress, IRSA over
node IAM, Kustomize over Helm, HPA on CPU, PodSecurity Standards `restricted`,
ECR image-tag bump via cross-repo PAT — recorded in the relevant code comments
and [`docs/tradeoffs.md`](../tradeoffs.md) rather than as separate files. They
were low-contention choices, not contested trade-offs.
