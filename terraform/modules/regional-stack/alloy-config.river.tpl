// Alloy River config — rendered into a ConfigMap by helm_release "alloy".
// Templated values (substituted at TF apply time): ${cluster_name}, ${region}.
// Secrets sourced from env vars (mounted from kubernetes_secret
// "grafana-cloud-credentials"): API_TOKEN; and per-backend URL + USERNAME
// pairs — {MIMIR,LOKI,TEMPO,PYROSCOPE}_URL and {MIMIR,LOKI,TEMPO,
// PYROSCOPE}_USERNAME (each Grafana Cloud backend has a distinct
// instance-ID username; only the API token is shared).

// ============================================================================
// Discovery
// ============================================================================
discovery.kubernetes "pods" {
  role = "pod"
}

discovery.kubernetes "nodes" {
  role = "node"
}

discovery.kubernetes "services" {
  role = "service"
}

// Filter for node-exporter pods (provisioned by the prometheus-node-exporter
// subchart in the monitoring namespace).
discovery.relabel "node_exporter" {
  targets = discovery.kubernetes.pods.targets

  rule {
    source_labels = ["__meta_kubernetes_namespace", "__meta_kubernetes_pod_label_app_kubernetes_io_name"]
    regex         = "monitoring;prometheus-node-exporter"
    action        = "keep"
  }
}

// Filter for kube-state-metrics.
discovery.relabel "kube_state_metrics" {
  targets = discovery.kubernetes.pods.targets

  rule {
    source_labels = ["__meta_kubernetes_namespace", "__meta_kubernetes_pod_label_app_kubernetes_io_name"]
    regex         = "monitoring;kube-state-metrics"
    action        = "keep"
  }
}

// Kubelet cAdvisor metrics — scraped from each node's :10250/metrics/cadvisor.
discovery.relabel "cadvisor" {
  targets = discovery.kubernetes.nodes.targets

  rule {
    target_label = "__address__"
    replacement  = "kubernetes.default.svc:443"
  }

  rule {
    source_labels = ["__meta_kubernetes_node_name"]
    regex         = "(.+)"
    target_label  = "__metrics_path__"
    replacement   = "/api/v1/nodes/$1/proxy/metrics/cadvisor"
  }
}

// ============================================================================
// Scrape jobs → forward to remote_write
// ============================================================================
prometheus.scrape "node_exporter" {
  targets    = discovery.relabel.node_exporter.output
  forward_to = [prometheus.relabel.add_labels.receiver]
  job_name   = "node-exporter"
}

prometheus.scrape "kube_state_metrics" {
  targets    = discovery.relabel.kube_state_metrics.output
  forward_to = [prometheus.relabel.add_labels.receiver]
  job_name   = "kube-state-metrics"
}

prometheus.scrape "cadvisor" {
  targets         = discovery.relabel.cadvisor.output
  forward_to      = [prometheus.relabel.add_labels.receiver]
  job_name        = "cadvisor"
  scheme          = "https"
  bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
  tls_config {
    insecure_skip_verify = true
  }
}

// EKS managed control-plane health — apiserver /metrics, scraped direct
// from the in-cluster kubernetes Service. node-exporter / kube-state-
// metrics / cAdvisor only see node + workload state; this is the one job
// that sees the AWS-managed control plane (apiserver request rate /
// latency / errors, etcd request latency as the apiserver reports it).
// EKS exposes /metrics; the grafana/alloy chart's default ClusterRole
// already grants the nonResourceURLs ["/metrics"] get, so no RBAC change
// is needed.
prometheus.scrape "apiserver" {
  targets = [
    { __address__ = "kubernetes.default.svc:443" },
  ]
  forward_to        = [prometheus.relabel.apiserver_keep.receiver]
  job_name          = "apiserver"
  scheme            = "https"
  bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
  tls_config {
    ca_file = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
  }
}

// Cardinality guard (Grafana Cloud free tier ~15k active series). The raw
// apiserver /metrics endpoint emits well over 10k series on its own —
// per-(verb,resource,scope) request-duration histogram buckets dominate.
// Keep only high-signal control-plane health metrics; keep the histogram
// _count/_sum (request rate + mean latency) but drop _bucket — health
// needs rate + errors, not apiserver-side quantiles.
prometheus.relabel "apiserver_keep" {
  forward_to = [prometheus.relabel.add_labels.receiver]

  rule {
    source_labels = ["__name__"]
    regex         = "up|apiserver_request_total|apiserver_request_duration_seconds_(count|sum)|apiserver_current_inflight_requests|apiserver_longrunning_requests|apiserver_storage_objects|etcd_request_duration_seconds_count|workqueue_depth|workqueue_adds_total|rest_client_requests_total"
    action        = "keep"
  }
}

// Inject cluster + region labels onto every metric (low cardinality,
// supports multi-region slicing in Grafana).
prometheus.relabel "add_labels" {
  forward_to = [prometheus.remote_write.mimir.receiver]

  rule {
    target_label = "cluster"
    replacement  = "${cluster_name}"
  }

  rule {
    target_label = "region"
    replacement  = "${region}"
  }
}

// ============================================================================
// OTLP receiver — app SDK pushes metrics + traces here.
// ============================================================================
otelcol.receiver.otlp "default" {
  grpc {
    endpoint = "0.0.0.0:4317"
  }

  output {
    metrics = [otelcol.processor.batch.default.input]
    traces  = [otelcol.processor.batch.default.input]
  }
}

otelcol.processor.batch "default" {
  output {
    metrics = [otelcol.exporter.prometheus.app.input]
    traces  = [otelcol.exporter.otlp.tempo.input]
  }
}

// OTel metrics → translate to Prometheus → remote_write to Mimir.
otelcol.exporter.prometheus "app" {
  forward_to = [prometheus.relabel.add_labels.receiver]
}

// OTel traces → Tempo via OTLP.
otelcol.exporter.otlp "tempo" {
  client {
    endpoint = sys.env("TEMPO_URL")
    auth     = otelcol.auth.basic.tempo.handler
  }
}

otelcol.auth.basic "tempo" {
  username = sys.env("TEMPO_USERNAME")
  password = sys.env("API_TOKEN")
}

// ============================================================================
// Logs — discover pods, tail container stdout, ship to Loki.
// ============================================================================
loki.source.kubernetes "pods" {
  targets    = discovery.kubernetes.pods.targets
  forward_to = [loki.process.add_labels.receiver]
}

loki.process "add_labels" {
  forward_to = [loki.write.default.receiver]

  stage.json {
    expressions = {
      level    = "level",
      msg      = "msg",
      trace_id = "trace_id",
      span_id  = "span_id",
    }
  }

  stage.labels {
    values = {
      level    = "level",
      trace_id = "trace_id",
    }
  }

  stage.static_labels {
    values = {
      cluster = "${cluster_name}",
      region  = "${region}",
    }
  }
}

loki.write "default" {
  endpoint {
    url = sys.env("LOKI_URL")
    basic_auth {
      username = sys.env("LOKI_USERNAME")
      password = sys.env("API_TOKEN")
    }
  }
}

// ============================================================================
// Pyroscope — receive HTTP from pyroscope-go SDK, forward to Pyroscope cloud.
// ============================================================================
pyroscope.receive_http "default" {
  http {
    listen_address = "0.0.0.0"
    listen_port    = 4040
  }
  forward_to = [pyroscope.write.default.receiver]
}

pyroscope.write "default" {
  endpoint {
    url = sys.env("PYROSCOPE_URL")
    basic_auth {
      username = sys.env("PYROSCOPE_USERNAME")
      password = sys.env("API_TOKEN")
    }
  }
  external_labels = {
    cluster = "${cluster_name}",
    region  = "${region}",
  }
}

// ============================================================================
// Mimir remote_write — terminus for all Prometheus-format metrics.
// ============================================================================
prometheus.remote_write "mimir" {
  endpoint {
    url = sys.env("MIMIR_URL")
    basic_auth {
      username = sys.env("MIMIR_USERNAME")
      password = sys.env("API_TOKEN")
    }
  }
}
