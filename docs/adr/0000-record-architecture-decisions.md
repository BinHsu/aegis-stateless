# AS-0000: Record architecture decisions

## Status

Accepted.

## Context

This repository is graded as much on *reasoning* as on running infrastructure.
A reviewer needs to see why each choice was made — and which alternatives were
weighed and rejected — without reverse-engineering it from Terraform.

## Decision

Keep Architecture Decision Records in `docs/adr/`, one file per significant
decision, in Nygard format (Status / Context / Decision / Consequences). Record
only contested or non-obvious decisions — low-contention choices live in code
comments instead, so the ADR set stays signal, not ceremony.

## Consequences

- The reasoning is reviewable and survives staff turnover.
- ADRs are immutable once Accepted; a reversal is a new ADR that supersedes,
  not an edit. (Several ADRs here carry an `amended` note where a later
  finding changed the implementation — see `AS-0020`.)
- A small tax on every significant change: write the ADR.
