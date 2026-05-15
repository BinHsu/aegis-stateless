# AS-0019: CI-driven apply with a branch-protection gate

## Status

Accepted. (Revised 2026-05-15 — supersedes the original "manual apply from the
operator's machine" decision.)

## Context

Terraform can be applied from an operator's laptop or from CI. Laptop apply is
simple but unaudited, depends on local credentials, and drifts from "git is the
source of truth". A CI apply needs an approval model so a merge cannot silently
mutate cloud infrastructure.

Two CI models exist: an Atlantis-style approval button *after* merge, or pure
GitOps where the merge *is* the apply and the PR review is the gate.

## Decision

CI-driven apply, pure-GitOps model. Push to `main` runs `infra-apply`
(`terraform apply` per env). The gate is the PR: `infra-plan` posts the plan
diff as a PR comment, and `main` branch protection requires the plan's status
check + linear history before merge. No post-merge approval button — the PR
review of the plan diff is the human gate, symmetric with how ArgoCD already
auto-applies Kubernetes changes.

Trust is split across two OIDC roles: a read-only role for PR plans (any ref),
and an apply role whose trust is pinned to `refs/heads/main` — a PR branch
cannot assume it.

`workflow_dispatch` (`infra-ops`) covers one-shots: bootstrap and the DR drill.

## Consequences

- Every infrastructure change is a reviewed, audited Git event.
- A bootstrap-ordering gap exists: before `platform` is applied, the IAM roles
  the workflows assume do not exist. A `BOOTSTRAP_COMPLETE` repo variable gates
  the plan/apply jobs — they skip cleanly until an operator has bootstrapped,
  keeping the pipeline green rather than failing on an unavoidable gap.
- The apply role is broad (`AdministratorAccess`); tightening it to
  least-privilege is deferred (`docs/tradeoffs.md`).
