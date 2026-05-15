# Grafana Alloy — in-cluster collector that:
#   - scrapes node-exporter / kube-state-metrics / cAdvisor (metrics)
#   - receives OTLP gRPC from app SDK (metrics + traces)
#   - receives Pyroscope ingest from app SDK (profiles)
#   - tails pod logs via loki.source.kubernetes (logs)
#   - remote_writes to Grafana Cloud (Mimir / Loki / Tempo / Pyroscope)
#
# Per locked observability decision: this replaces Fluent Bit + the CW
# observability addon. No CloudWatch dashboards / alarms in scope.

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      # Alloy + subcharts use hostPath / hostNetwork (node-exporter) and
      # need to read kubelet metrics, so the namespace runs `privileged`
      # PSS — not the restricted profile applied to the workload ns.
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "baseline"
      "pod-security.kubernetes.io/warn"    = "baseline"
    }
  }
}

# K8s Secret holding GC credentials. TF reads SSM at regional/ env scope
# (data.aws_ssm_parameter) and passes values in as sensitive module vars.
# Alloy mounts these as env vars and references in its config via env().
resource "kubernetes_secret" "grafana_cloud" {
  metadata {
    name      = "grafana-cloud-credentials"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    api_token             = var.gc_api_token
    remote_write_username = var.gc_remote_write_username
    mimir_url             = var.gc_mimir_url
    loki_url              = var.gc_loki_url
    tempo_url             = var.gc_tempo_url
    pyroscope_url         = var.gc_pyroscope_url
  }

  type = "Opaque"
}

# ---- node-exporter (pinned subchart) --------------------------------------
resource "helm_release" "node_exporter" {
  name       = "prometheus-node-exporter"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-node-exporter"
  version    = "4.41.0" # pinned

  values = [yamlencode({
    service = {
      port = 9100
    }
  })]
}

# ---- kube-state-metrics (pinned subchart) ---------------------------------
resource "helm_release" "kube_state_metrics" {
  name       = "kube-state-metrics"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-state-metrics"
  version    = "5.25.1" # pinned
}

# ---- Alloy ----------------------------------------------------------------
resource "helm_release" "alloy" {
  name       = "alloy"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://grafana.github.io/helm-charts"
  chart      = "alloy"
  version    = "0.10.1" # pinned

  values = [
    yamlencode({
      controller = {
        # DaemonSet — one Alloy per node so OTLP/Pyroscope receive_http
        # binds to host network for direct app-pod-to-collector traffic
        # via NODE_IP without crossing a Service.
        type = "daemonset"
      }
      alloy = {
        # Mount the GC credentials secret as env vars.
        envFrom = [{
          secretRef = {
            name = kubernetes_secret.grafana_cloud.metadata[0].name
          }
        }]
        # Expose host ports for OTLP gRPC (4317) and Pyroscope (4040)
        # so app pods can reach via $(NODE_IP):4317 / :4040.
        extraPorts = [
          {
            name       = "otlp-grpc"
            port       = 4317
            targetPort = 4317
            protocol   = "TCP"
          },
          {
            name       = "pyroscope"
            port       = 4040
            targetPort = 4040
            protocol   = "TCP"
          },
        ]
        configMap = {
          create = true
          content = templatefile("${path.module}/alloy-config.river.tpl", {
            cluster_name = local.cluster_name
            region       = var.region
          })
        }
      }
    })
  ]

  depends_on = [
    kubernetes_secret.grafana_cloud,
    helm_release.node_exporter,
    helm_release.kube_state_metrics,
  ]
}
