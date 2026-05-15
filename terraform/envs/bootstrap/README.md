# bootstrap env

Creates the S3 bucket + DynamoDB lock table that the `platform/` and `regional/` envs use as their remote backend.

## Apply once, never destroy

This env's own state is **local** (gitignored `terraform.tfstate`) by design: migrating bootstrap state into the very bucket it provisions would create a chicken-and-egg cycle. Bootstrap is intentionally one-shot.

The bucket and lock table have `lifecycle { prevent_destroy = true }`. To remove them, an operator must edit those blocks first — guarding against accidental `terraform destroy`.

## Usage

```bash
make bootstrap   # local-state apply
```

After apply, the Makefile reads the `backend_hcl` output and writes a `backend.hcl` file at repo root (gitignored). Downstream envs then run `terraform init -backend-config=$(ROOT)/backend.hcl`.

## What it creates

| Resource | Why |
|---|---|
| S3 bucket `aegis-stateless-tfstate-${account_id}` | Remote state for platform + regional. Versioned + SSE-KMS (`alias/aws/s3`) + Block Public Access. |
| DynamoDB table `aegis-stateless-tfstate-lock` | State locking. PAY_PER_REQUEST. Point-in-time recovery on. |

## Production hardening (out of scope, documented in tradeoffs)

- Customer-managed KMS key (granular key policy + cross-account access) instead of `aws/s3`.
- S3 Object Lock for compliance write-once semantics.
- Cross-region replication of the state bucket for region-failure resilience.
