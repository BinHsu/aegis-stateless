# AS-0020: Pattern X — multi-region topology as data, external orchestration

## Status

Accepted. (Amended 2026-05-15 — the implementation changed; see below.)

## Context

The multi-region requirement has two parts: (R1) a single source of truth for
which regions are deployed, and (R2) adding the Nth region must be a data
change, not a code-structure change — no copied directories, no new HCL blocks.

The original design used Terraform `provider for_each` to generate one provider
alias per region from a `var.regions` map. On implementation this failed:
`for_each` on `provider` blocks is a reserved-but-unimplemented Terraform
feature (verified against the 1.16-alpha changelog). It has been "planned" since
2024 with no shipped release.

## Decision

The topology is data: `regions.auto.tfvars.json` at the repo root holds
`platform_region` plus a `regions{}` map, each entry carrying `enabled`, CIDR,
and node sizing. JSON (not HCL) because both Terraform and `jq` parse it
natively; `enabled: false` expresses "designed but not deployed" since JSON has
no comments.

Multi-region is realised by **external orchestration**, not in-Terraform
iteration. The `regional` environment handles exactly one region per apply
(single static provider). The Makefile and the GitHub Actions matrix loop over
the enabled regions (`jq` filter) and invoke `regional` once each, with a
per-region state key (`regional/<region>/terraform.tfstate`).

## Consequences

- R1 + R2 both satisfied: adding a region is a one-line edit to the JSON; the
  loop picks it up. No `.tf` edit, no directory copy.
- **Better than the original design**, not merely a workaround: per-region
  state means per-region blast-radius isolation, parallel applies, canary
  rollout, and granular DR (destroy one region, leave others). This dissolves
  the "single state for N regions" trade-off the original would have carried.
- The orchestration logic lives in the Makefile + workflows, not in Terraform —
  a deliberate boundary. Terragrunt would absorb it; that is deferred
  (`AS-0021`) until DAG complexity across envs/accounts justifies the tool.
