# AS-0013: Single region applied, multi-region designed

## Status

Accepted.

## Context

A stateless greeter behind a load balancer is a natural multi-region HA
candidate. But a full active-active multi-region deployment — N EKS control
planes, cross-region replication, latency-routed DNS — costs real money and
exceeds a cost-bounded take-home budget.

## Decision

Design for multi-region, deploy one. The `regional` environment and its module
are fully region-parameterised (see `AS-0020`); `regions.auto.tfvars.json`
enables exactly one region (`eu-central-1`). A second region is present in the
data file as a complete, disabled entry — activating it is flipping
`enabled: true`.

## Consequences

- The resilience *story* is demonstrable (the DR drill, `AS-0026`) without
  paying for two live regions.
- Honest failure mode: a region-wide outage is a service outage. There is no
  cross-region failover. Stated plainly in `docs/tradeoffs.md`.
- Adding the second region is a data change, not an architecture change — the
  cost of the deferral is one line, not a redesign.
