# regional env

Per-region workload infrastructure: VPC + EKS + IRSA + ALB controller + per-cluster ArgoCD + Grafana Alloy DaemonSet. **Applied once per region by an external loop** (Makefile or GH Actions matrix), not as a single multi-region apply.

This design avoids the TF `provider for_each` limitation (reserved-but-not-implemented as of TF 1.16-alpha, verified 2026-05-15) and trades a single-state-for-N-regions blast radius for per-region state isolation — adding canary, parallel apply, and granular DR drill as side-effects. See `AS-0020 (amended)` + `AS-0021 (amended)`.

## Pattern X data flow

```
regions.auto.tfvars.json (single source of truth, repo root)
              │
   ┌──────────┼──────────────────────┐
   │          │                      │
 platform/    Makefile / CI loop     external-dns (future, in-cluster)
 var.regions  jq → per-region scalars   reads cluster context for
 (full map)        │                    set-identifier on Ingress
                   ▼
            this env, once per region
            (regional/<region>/terraform.tfstate)
```

## Apply

Local:
```bash
make regional                                # loops over enabled regions
make regional REGION=eu-west-1               # single-region (matches enabled flag)
make destroy-region REGION=eu-central-1      # granular DR drill target
```

CI (canonical): `infra-apply.yml` workflow, push to `main`, GH Actions matrix over `jq '.regions | to_entries[] | select(.value.enabled) | .key' regions.auto.tfvars.json`. Parallel applies per region — each has its own state, its own lock, its own blast radius.

## Per-region state key

`regional/<region>/terraform.tfstate` in the bootstrap-provisioned bucket. Passed via `-backend-config="key=regional/$REGION/terraform.tfstate"` in `terraform init`.

## Sensitive vars

| Var | Local | CI |
|---|---|---|
| `github_token` | gitignored `secrets.auto.tfvars` in this dir | GH Actions secret `GH_DEPLOY_KEY_PAT`, injected as `TF_VAR_github_token` |

## Provider config note

`kubernetes` + `helm` providers use `exec` auth (calls `aws eks get-token` at apply time) — tolerates first-apply where the cluster doesn't exist yet at plan time. Standard pattern from `terraform-aws-modules/eks` examples.

## DR drill (per-region granular)

```bash
# tear down a single region
make destroy-region REGION=eu-central-1

# … observe GC dashboard: that region's metrics drop, others (if any) untouched

# rebuild
make regional REGION=eu-central-1
# 20-30 min EKS cold-provisioning cycle (AS-0026)

# … observe GC dashboard: metrics return
```

Compared to single-state design: the platform env, the ECR repo, Grafana dashboards, and OTHER regions' workloads remain untouched. True per-region blast-radius isolation.
