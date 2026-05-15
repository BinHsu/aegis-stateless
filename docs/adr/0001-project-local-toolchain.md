# AS-0001: Project-local Terraform toolchain

## Status

Accepted.

## Context

The repo needs `terraform`, `tflint`, `tfsec`, `kubeconform`, `hadolint`, `jq`,
`kustomize`, and `gitleaks`. Installing those onto the host (`brew install …`)
causes version drift between contributors and CI, and pollutes a reviewer's
machine when they clone to evaluate.

## Decision

Every tool lives inside the project. `scripts/install-tools.sh` fetches pinned
versions, verifies each against its published SHA256, and extracts to `./bin/`
(gitignored). The `Makefile` prepends `./bin/` to `PATH`. The Terraform binary
is pinned by `.terraform-version` (read by `tfenv`/`tenv`); every root module
pins `required_version` and provider versions.

## Consequences

- `git clone && make dev-setup` reproduces the exact toolchain — no host
  install, no `sudo`, no version drift.
- CI runs the *same* `install-tools.sh`, so local and CI tool versions match.
- One platform gap: `hadolint` ships no native darwin/arm64 build and its
  x86_64 build segfaults under Rosetta, so it is skipped on Apple Silicon —
  the Linux CI runner covers Dockerfile linting. Documented in the script.
- Cost: a bespoke install script to maintain instead of a one-line `brew`.
  Accepted — reproducibility for a reviewer outweighs it.
