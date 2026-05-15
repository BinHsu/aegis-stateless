# AS-0015: Per-cluster ArgoCD over hub-spoke

## Status

Accepted.

## Context

ArgoCD can run hub-spoke — one central ArgoCD managing many remote clusters via
`argocd cluster add` — or per-cluster, where each cluster runs its own ArgoCD
managing only itself.

Hub-spoke centralises the GitOps control plane: fewer installs, one UI. But the
hub becomes a single point of failure and a cross-cluster blast radius — a hub
outage, or a compromised hub credential, reaches every cluster.

## Decision

Each EKS cluster runs its own ArgoCD, installed by `modules/regional-stack`
(`argocd.tf`). Each ArgoCD has one `Application` pointing at this repo's
`k8s/overlays/prod/`. No `ApplicationSet`, no cross-cluster RBAC, no
`argocd cluster add`.

## Consequences

- No GitOps-layer SPOF: a region's ArgoCD failure is contained to that region.
- Each region is self-sufficient — it reconciles itself from git with no
  dependency on a hub.
- Repo authentication is per-cluster: a dedicated read-only ED25519 deploy key
  per region (see `AS-0025`), so a leaked key has repo-only, not
  account-wide, scope.
- Cost: N ArgoCD installs instead of one, and no single pane of glass across
  clusters. At this scale (1 region, designed for a handful) that is a
  non-issue; a fleet of dozens would revisit this.
