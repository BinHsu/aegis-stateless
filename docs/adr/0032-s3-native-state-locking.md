# AS-0032: S3 native state locking over DynamoDB

## Status

Accepted.

## Context

The conventional Terraform S3 remote backend pairs the state bucket with a
DynamoDB table for state locking — a second resource, a second thing to
provision, tag, and pay for.

Terraform 1.10 introduced `use_lockfile`: native locking via an S3
conditional-write (`PutObject` with `If-None-Match`), which is the atomic
create-if-absent primitive a lock needs. Terraform 1.11 marked it stable and
**deprecated** the DynamoDB locking arguments, slated for removal in a future
minor version.

## Decision

Use S3 native locking. The `bootstrap` environment creates only the state
bucket — no DynamoDB table. Each downstream backend block sets
`use_lockfile = true`; the lock lives at `<state-key>.tflock` in the same
bucket. The Terraform binary is pinned to 1.14.8 and `required_version` to
`~> 1.11` to guarantee the feature is present.

## Consequences

- One fewer resource to provision and pay for; the lock is co-located with the
  state it guards.
- Adopting it from day one avoids a future forced migration when DynamoDB
  locking is removed upstream.
- The CI plan jobs run `terraform plan -lock=false`: the read-only plan IAM
  role cannot write the `.tflock` object, and a plan does not mutate state so
  the lock is unnecessary. Apply jobs (write role) lock normally.
