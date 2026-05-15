# aegis-stateless

Infrastructure for a stateless HTTP greeter on AWS EKS — Terraform for the cloud
substrate, ArgoCD for in-cluster GitOps, Grafana Cloud for observability, and a
DR drill that rebuilds the workload from git.

This repository is the **infrastructure half** of a two-repo split. The
application (a Go `net/http` greeter, its Dockerfile, and the image-publish CI)
lives in the sibling repo `aegis-greeter`. This repo owns the AWS infrastructure,
the Kubernetes manifests, the ArgoCD installation, and the CI/CD that ties them
together.

## Architecture

```
  ┌─────────────────────┐         ┌──────────────────────────────────────┐
  │  aegis-greeter       │         │  aegis-stateless  (this repo)        │
  │  (application repo)  │         │                                      │
  │                      │  push   │  terraform/   k8s/   .github/        │
  │  greeter.go          │── ECR ─▶│   envs/        base/   workflows/    │
  │  Dockerfile          │         │   modules/     overlays/prod/        │
  │  .github/publish.yml │  commit │                                      │
  │                      │── bump ▶│  k8s/overlays/prod/kustomization.yaml│
  └─────────────────────┘  image    │            │                        │
                            tag      │            ▼                        │
                                     │     ArgoCD (per cluster)            │
                                     │            │                        │
  ┌──────────────────────────────────┼────────────▼───────────────────────┐
  │  AWS  (per region, via Pattern X) │      EKS cluster                    │
  │                                   │   ┌──────────────────────────────┐ │
  │  VPC (3 AZ) ─ EKS ─ ALB           │   │ greeter Deployment (2+ pods) │ │
  │  IRSA ─ ECR ─ Route 53            │   │ Grafana Alloy DaemonSet      │ │
  │                                   │   └──────────────┬───────────────┘ │
  └───────────────────────────────────┼──────────────────┼─────────────────┘
                                       │                  │ OTLP / logs /
                                       │                  │ profiles / scrape
                                       ▼                  ▼
                              CloudWatch (audit       Grafana Cloud
                              side-effect only)       (Mimir/Loki/Tempo/
                                                       Pyroscope)
```

- **Terraform**, three lifecycle-separated environments: `bootstrap` (state
  backend), `platform` (slow lifecycle — Route 53, ECR, OIDC, budgets, Grafana
  dashboards), `regional` (fast lifecycle — VPC + EKS + ArgoCD + Alloy, applied
  once per region).
- **Pattern X** — the multi-region topology is data (`regions.auto.tfvars.json`),
  not code. Adding a region is a one-line data change; an external loop
  (Makefile / GitHub Actions matrix) applies `regional` once per region with
  per-region state isolation.
- **ArgoCD per cluster** — each EKS cluster runs its own ArgoCD, eliminating a
  GitOps-layer single point of failure.
- **Observability** — the app emits OpenTelemetry + Pyroscope to a node-local
  Grafana Alloy DaemonSet, which forwards to Grafana Cloud. CloudWatch is kept
  only for EKS control-plane logs + ALB access logs (audit side-effect).

See [`docs/adr/`](docs/adr/) for the reasoning behind each decision and
[`docs/tradeoffs.md`](docs/tradeoffs.md) for what was deliberately deferred.

## Repository layout

```
regions.auto.tfvars.json   Single source of truth — platform_region + regions{}
terraform/
  envs/bootstrap/          S3 state bucket (local state, one-shot)
  envs/platform/           Route 53, ECR, OIDC, budget, SSM, Grafana, branch protection
  envs/regional/           VPC + EKS + ArgoCD + Alloy — applied once per region
  modules/regional-stack/  The per-region stack, invoked by envs/regional/
k8s/
  base/                    Kustomize base — namespace, deployment, service, ingress, hpa
  overlays/prod/           Image tag bumped by the aegis-greeter CI
grafana/dashboards/        Dashboard JSON, applied by the grafana/grafana TF provider
.github/workflows/         infra-plan, infra-apply, infra-ops
docs/adr/                  Architecture Decision Records
docs/tradeoffs.md          Deferred work + production-hardening path
Makefile                   Local dev + emergency apply (CI is the canonical path)
scripts/install-tools.sh   Pinned project-local toolchain → ./bin/
```

## Prerequisites

- An AWS account with permission to create VPC / EKS / IAM / ECR / Route 53 / S3.
- A Grafana Cloud stack (free tier is sufficient).
- `terraform` ≥ 1.11 (`.terraform-version` pins 1.14.8 for `tfenv`/`tenv`).
- `make`, `git`, `aws` CLI, `bash`. All other tools install into `./bin/`.

## First-time setup

The CI pipeline cannot create the very infrastructure it authenticates against,
so the foundation is bootstrapped once from an operator's machine; CI takes over
after that.

```bash
# 1. Project-local toolchain → ./bin/  (tflint, tfsec, kubeconform, hadolint,
#    jq, kustomize, gitleaks) + wire the pre-commit hook.
make dev-setup

# 2. Fill in secrets (templates ship as *.example):
cp terraform/envs/platform/secrets.auto.tfvars.example terraform/envs/platform/secrets.auto.tfvars
cp terraform/envs/regional/secrets.auto.tfvars.example terraform/envs/regional/secrets.auto.tfvars
# …edit both with real Grafana Cloud + GitHub PAT values (gitignored).

# 3. Create the remote state backend (local state, one-shot).
export AWS_PROFILE=<your-profile>
make bootstrap

# 4. Apply the slow-lifecycle platform env.
make platform

# 5. Apply the workload, looping over enabled regions.
make regional
```

After `make platform`, capture its outputs and finish the CI wiring:

```bash
# GitHub Actions secrets (12) — see terraform/envs/platform/README.md for the
# full gh secret set commands.
# GitHub Actions repo variables for the sibling app repo:
gh variable set ECR_REPO_URL  -b "$(terraform -chdir=terraform/envs/platform output -raw ecr_repository_url)"  --repo BinHsu/aegis-greeter
gh variable set ECR_REGISTRY  -b "$(terraform -chdir=terraform/envs/platform output -raw ecr_registry)"        --repo BinHsu/aegis-greeter
gh variable set OIDC_ROLE_ARN -b "$(terraform -chdir=terraform/envs/platform output -raw greeter_ci_role_arn)" --repo BinHsu/aegis-greeter
gh variable set AWS_REGION    -b "$(terraform -chdir=terraform/envs/platform output -raw aws_region)"          --repo BinHsu/aegis-greeter

# Flip the CI bootstrap gate — infra-plan/infra-apply plan/apply jobs un-skip.
gh variable set BOOTSTRAP_COMPLETE -b "true" --repo BinHsu/aegis-stateless
```

From here, every push to `main` runs `infra-plan` (PR) / `infra-apply`
(merge); see [CI/CD](#cicd) below.

## Day-to-day operations

```bash
make help          # list every target
make fmt           # terraform fmt -recursive
make validate      # terraform validate, all envs
make lint          # tflint
make sec           # tfsec
make platform      # apply the platform env
make regional      # apply every enabled region
make regional-one REGION=eu-central-1   # apply a single region
```

The pre-commit hook (`.githooks/pre-commit`, wired by `make dev-setup`) runs
`terraform fmt -check` + a `gitleaks` secret scan on every commit.

## DR drill

The drill demonstrates that the workload is reconstructible from git — Terraform
state is the source of truth, ArgoCD converges the cluster from zero.

```bash
# Tear down one region's workload. The platform env (Route 53, ECR, Grafana
# dashboards) is untouched; other regions, if any, stay alive.
make destroy-region REGION=eu-central-1

# Rebuild it. EKS cold-provisioning dominates the ~20-30 min cycle.
make regional-one REGION=eu-central-1
```

Or run it through GitHub Actions: the `infra-ops` workflow (`workflow_dispatch`)
exposes `destroy-region` as an operator-triggered, audit-logged operation.

Measured cycle: EKS control plane ~15 min + node group & addons ~5 min + ALB
target health & DNS ~1-3 min + ArgoCD sync ~30 s. See ADR `AS-0026`.

## Observability

The app emits metrics, traces, logs, and continuous profiles via OpenTelemetry +
Pyroscope to a node-local Grafana Alloy DaemonSet, which forwards to Grafana
Cloud. Dashboards and alert rules are declared in Terraform
(`terraform/envs/platform/grafana.tf` + `grafana/dashboards/`) — no manual UI
edits, so the DR drill reconstructs them from git.

Sample queries (full set in `docs/runbooks/`):

```promql
# request latency p95
histogram_quantile(0.95,
  sum by (le, route) (rate(http_server_request_duration_seconds_bucket{service_name="aegis-greeter"}[5m])))
```
```logql
# 5xx log lines in the last hour, by pod
sum by (pod) (count_over_time(
  {app="aegis-greeter"} | json | level="ERROR" | status >= 500 [1h]))
```

## CI/CD

| Workflow | Trigger | Does |
|---|---|---|
| `infra-plan` | PR / push to `main` | fmt, validate, tflint, tfsec, kubeconform, gitleaks, `terraform plan` per env; posts the plan diff as a PR comment |
| `infra-apply` | push to `main` | `terraform apply` per env (platform + regional matrix) |
| `infra-ops` | `workflow_dispatch` | `bootstrap` / `destroy-region` / `destroy-platform` (the DR drill) |

`main` is protected: required status checks + linear history + no force-push.
Two OIDC roles split trust — a read-only role for PR plans, an apply role whose
trust is pinned to `refs/heads/main`. Until the `BOOTSTRAP_COMPLETE` repo
variable is set, the plan/apply jobs skip cleanly (the AWS foundation does not
exist yet) and the pipeline stays green.

## License

MIT — see [`LICENSE`](LICENSE).
