# AS-0021: Three-environment lifecycle split

## Status

Accepted.

## Context

One Terraform state for everything couples resources with very different change
cadences and blast radii: a state-backend bucket (created once, never touched)
versus an EKS cluster (destroyed and rebuilt in every DR drill). A single state
also means a single lock and a single blast radius.

## Decision

Three root environments, split by lifecycle:

- **`bootstrap`** — region-invariant, *local* state. Creates only the S3 state
  bucket. Applied once; never again. (Its state cannot live in the bucket it
  creates — chicken-and-egg.)
- **`platform`** — slow lifecycle. Route 53, ECR, GitHub OIDC roles, AWS Budget,
  SSM parameters, Grafana dashboards, branch protection. Survives a DR drill.
- **`regional`** — fast lifecycle. VPC + EKS + ArgoCD + Alloy, applied once per
  region. This is the DR drill target.

## Consequences

- A DR drill destroys `regional` only; `platform` (the zone, the ECR images,
  the dashboards) is untouched — the drill rebuilds the workload, not the world.
- Each environment has its own state file and lock — independent blast radii.
- `regional` further splits state per region (`AS-0020`), so blast radius is
  one region, not all.
- Cost: three `terraform apply` invocations and cross-env wiring via
  `terraform_remote_state`. The Makefile / CI hides the sequencing.
- Terragrunt would manage this DAG declaratively. Deferred: at three envs the
  raw-Terraform + Makefile cost is lower than adding the tool + an ADR to
  justify it. Revisit when cross-account or deeper DAG dependencies appear.
