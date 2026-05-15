# platform env

Slow-lifecycle infrastructure that **survives the DR drill**: Route 53 hosted zone, ECR repo (+ replication rule when ≥ 2 regions deployed), AWS Budget alarm, GitHub OIDC providers + trust roles, SSM Parameter Store entries for Grafana Cloud credentials, ALB access-logs S3 bucket, and Grafana Cloud dashboards / alerts / contact points (via the `grafana/grafana` TF provider).

## Apply

```bash
make platform
```

The Makefile target runs `terraform init -backend-config=$(ROOT)/backend.hcl` (file generated from `bootstrap`'s outputs) and applies with `-var-file=$(ROOT)/regions.auto.tfvars`.

## Sensitive vars (NEVER committed)

Provide via a gitignored `secrets.auto.tfvars` in this directory, or via `-var` flags / `TF_VAR_<name>` env vars:

| Var | Where to get it |
|---|---|
| `grafana_cloud_api_token` | Grafana Cloud → Connections → Cloud Access Policies → create token with admin scope on the aegis stack |
| `grafana_cloud_remote_write_username` | Grafana Cloud → Connections → for each backend (Mimir/Loki/Tempo/Pyroscope) → user ID |
| `grafana_cloud_mimir_url` / `_loki_url` / `_tempo_url` / `_pyroscope_url` | Same Connections pages — push/ingest URLs per backend |
| `budget_alert_email` | Operator-controlled email address |
| `github_token` | GitHub fine-grained PAT with `admin:public_key` on the aegis-stateless repo (for regional-stack's deploy-key registration) |

All marked `sensitive = true`; not echoed in `terraform plan` output.

## Drift detection

After every apply, `terraform plan` should report **zero diff** — including Grafana resources. Any drift indicates a manual UI edit, which is forbidden per the locked observability discipline.

## Outputs consumed by regional/

`platform/` exports `zone_id`, `ecr_url`, `oidc_role_arns`, `grafana_cloud_ssm_paths`, `alb_access_logs_bucket`, `public_dashboard_urls`. `regional/` reads these via `data.terraform_remote_state.platform`.
