# Architecture Decision Records

Each ADR captures one significant decision: the context that forced it, the
decision taken, and the consequences accepted. Format follows Michael Nygard's
template (Status / Context / Decision / Consequences).

IDs use the `AS-` prefix (aegis-stateless) to distinguish them from the sibling
app repo's `AG-` records.

| ADR | Decision | Status |
|---|---|---|
| [AS-0000](0000-record-architecture-decisions.md) | Record architecture decisions | Accepted |
| [AS-0001](0001-project-local-toolchain.md) | Project-local Terraform toolchain | Accepted |
| [AS-0013](0013-single-region-applied-multi-region-designed.md) | Single region applied, multi-region designed | Accepted |
| [AS-0015](0015-per-cluster-argocd.md) | Per-cluster ArgoCD over hub-spoke | Accepted |
| [AS-0019](0019-ci-driven-apply.md) | CI-driven apply with a branch-protection gate | Accepted |
| [AS-0020](0020-pattern-x-external-orchestration.md) | Pattern X — multi-region as data, external orchestration | Accepted |
| [AS-0021](0021-three-env-lifecycle-split.md) | Three-environment lifecycle split | Accepted |
| [AS-0026](0026-dr-drill-rto.md) | DR drill — measured RTO, not a round number | Accepted |
| [AS-0028](0028-observability-grafana-cloud.md) | Observability on Grafana Cloud free tier | Accepted |
| [AS-0032](0032-s3-native-state-locking.md) | S3 native state locking over DynamoDB | Accepted |

Smaller decisions (Deployment over StatefulSet, EKS managed control plane,
ALB Ingress, IRSA over node IAM, Kustomize over Helm, HPA on CPU, PodSecurity
Standards `restricted`, ECR image-tag bump via cross-repo PAT) are recorded in
the relevant code comments and `docs/tradeoffs.md` rather than as separate
files — they were low-contention choices, not contested trade-offs.
