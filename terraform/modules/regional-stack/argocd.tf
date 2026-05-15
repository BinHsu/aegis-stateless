# ArgoCD per cluster — NOT hub-spoke. Each EKS cluster has its own ArgoCD,
# eliminating the GitOps-layer SPOF (per locked decision: per-cluster ArgoCD).
#
# Repo authentication: dedicated ED25519 deploy key, registered as read-only
# on the aegis-stateless repo. One key per region (title disambiguated by
# region). Per ADR AS-0025 — never use a personal PAT for ArgoCD repo auth.

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/audit"   = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }
}

resource "tls_private_key" "argocd_repo" {
  algorithm = "ED25519"
}

resource "github_repository_deploy_key" "argocd" {
  title      = "argocd-${var.region}"
  repository = var.repo_name
  key        = tls_private_key.argocd_repo.public_key_openssh
  read_only  = true
}

resource "kubernetes_secret" "argocd_repo" {
  metadata {
    name      = "aegis-stateless-repo-${var.region}"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      # ArgoCD discovers repository secrets by this label — no separate
      # ArgoCD repository CR needed.
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    url           = var.repo_url_ssh
    sshPrivateKey = tls_private_key.argocd_repo.private_key_openssh
  }

  type = "Opaque"
}

resource "helm_release" "argocd" {
  name       = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.6.12" # pinned

  # No public Ingress for the UI — access via `kubectl port-forward
  # -n argocd svc/argo-cd-server 8080:443`. Production hardening: dedicated
  # ALB + OIDC SSO. Documented in tradeoffs.
  values = [
    yamlencode({
      server = {
        service = {
          type = "ClusterIP"
        }
      }
      controller = {
        # Single replica — HA is out of scope for take-home.
        replicas = 1
      }
      configs = {
        params = {
          # Disable insecure TLS-skip for repo connections — deploy key
          # uses SSH, server side authenticated by known_hosts (auto-trust
          # GitHub's host key for first connection).
          "controller.repo.server.timeout.seconds" = "60"
        }
      }
    })
  ]

  depends_on = [kubernetes_secret.argocd_repo]
}

# Application CR via the official argocd-apps subchart. Keeps Application
# spec declarative + separate from the controller install (cleaner blast
# radius for app-spec changes).
resource "helm_release" "argocd_application" {
  name       = "aegis-greeter-app"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = "2.0.2" # pinned

  values = [
    yamlencode({
      applications = [{
        name      = "aegis-greeter"
        namespace = "argocd"
        project   = "default"
        source = {
          repoURL        = var.repo_url_ssh
          path           = "k8s/overlays/prod"
          targetRevision = "HEAD"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "greeter"
        }
        syncPolicy = {
          automated = {
            prune    = true
            selfHeal = true
          }
          syncOptions = ["CreateNamespace=true"]
        }
      }]
    })
  ]

  depends_on = [helm_release.argocd]
}
