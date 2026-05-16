# Grafana Cloud dashboards + alerts via the `grafana/grafana` TF provider.
# Manual UI edits are forbidden — the DR drill must reconstruct the entire
# observability surface from git. `terraform plan` post-apply must show zero
# diff if no manual edits leaked in.

# ---- data source lookup ---------------------------------------------------
# Grafana Cloud auto-provisions named data sources for the bundled backends.
# Convention: "grafanacloud-<stack>-prom" / "...-logs" / "...-traces" /
# "...-profiles". If the stack slug differs, adjust the names below.
data "grafana_data_source" "prometheus" {
  name = "grafanacloud-aegis-prom"
}

# ---- folder ---------------------------------------------------------------
resource "grafana_folder" "aegis_stateless" {
  title = "aegis-stateless"
  uid   = "aegis-stateless"
}

# ---- dashboards -----------------------------------------------------------
resource "grafana_dashboard" "greeter_overview" {
  folder = grafana_folder.aegis_stateless.uid
  config_json = templatefile("${path.module}/../../../grafana/dashboards/greeter-overview.json", {
    prometheus_uid = data.grafana_data_source.prometheus.uid
  })
  overwrite = true
}

# Public-share link for the reviewer (no GC account required to view).
resource "grafana_dashboard_public" "greeter_overview" {
  dashboard_uid = grafana_dashboard.greeter_overview.uid
  is_enabled    = true
  share         = "public"
}

# ---- alert routing --------------------------------------------------------
resource "grafana_contact_point" "ops_email" {
  name = "ops-email"

  email {
    addresses = [var.budget_alert_email]
  }
}

resource "grafana_notification_policy" "main" {
  contact_point   = grafana_contact_point.ops_email.name
  group_by        = ["alertname", "grafana_folder"]
  group_wait      = "30s"
  group_interval  = "5m"
  repeat_interval = "4h"
}

# ---- alert rules ----------------------------------------------------------
# One rule_group per alert keeps blast radius small (a single rule update
# doesn't touch unrelated groups). All four representative alerts follow the
# same shape: a `data` block with the metric query (refId "A"), a `data`
# block with a threshold expression (refId "C") referencing "A".

resource "grafana_rule_group" "five_xx_rate" {
  name             = "5xx-rate"
  folder_uid       = grafana_folder.aegis_stateless.uid
  interval_seconds = 60

  rule {
    name           = "5xx rate > 5% over 5 min"
    for            = "5m"
    condition      = "C"
    no_data_state  = "NoData"
    exec_err_state = "Error"

    data {
      ref_id         = "A"
      datasource_uid = data.grafana_data_source.prometheus.uid
      relative_time_range {
        from = 300
        to   = 0
      }
      model = jsonencode({
        editorMode = "code"
        expr       = "sum(rate(http_server_request_duration_seconds_count{service_name=\"aegis-greeter\",http_response_status_code=~\"5..\"}[5m])) / clamp_min(sum(rate(http_server_request_duration_seconds_count{service_name=\"aegis-greeter\"}[5m])), 1e-9)"
        intervalMs = 1000
        instant    = true
        refId      = "A"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        type       = "threshold"
        refId      = "C"
        expression = "A"
        conditions = [{
          type      = "query"
          evaluator = { type = "gt", params = [0.05] }
          operator  = { type = "and" }
          query     = { params = ["A"] }
        }]
      })
    }

    # __dashboardUid__ / __panelId__ link this alert to its dashboard panel:
    # Grafana shows the alert state on the panel and offers a jump-to-panel
    # link from the alert. The query stays a separate copy — the link makes
    # any drift between alert and panel visible at a click.
    annotations = {
      summary          = "aegis-greeter 5xx rate exceeded 5% over 5 min"
      __dashboardUid__ = grafana_dashboard.greeter_overview.uid
      __panelId__      = "2"
    }
    labels = {
      severity = "critical"
    }
  }
}

resource "grafana_rule_group" "p95_latency" {
  name             = "p95-latency"
  folder_uid       = grafana_folder.aegis_stateless.uid
  interval_seconds = 60

  rule {
    name           = "p95 latency > 1 s over 5 min"
    for            = "5m"
    condition      = "C"
    no_data_state  = "NoData"
    exec_err_state = "Error"

    data {
      ref_id         = "A"
      datasource_uid = data.grafana_data_source.prometheus.uid
      relative_time_range {
        from = 300
        to   = 0
      }
      model = jsonencode({
        editorMode = "code"
        expr       = "histogram_quantile(0.95, sum by (le) (rate(http_server_request_duration_seconds_bucket{service_name=\"aegis-greeter\"}[5m])))"
        intervalMs = 1000
        instant    = true
        refId      = "A"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        type       = "threshold"
        refId      = "C"
        expression = "A"
        conditions = [{
          type      = "query"
          evaluator = { type = "gt", params = [1.0] }
          operator  = { type = "and" }
          query     = { params = ["A"] }
        }]
      })
    }

    annotations = {
      summary          = "aegis-greeter p95 request latency exceeded 1 s over 5 min"
      __dashboardUid__ = grafana_dashboard.greeter_overview.uid
      __panelId__      = "3"
    }
    labels = {
      severity = "warning"
    }
  }
}

resource "grafana_rule_group" "pod_ready" {
  name             = "pod-ready"
  folder_uid       = grafana_folder.aegis_stateless.uid
  interval_seconds = 60

  rule {
    name           = "aegis-greeter has no ready pods over 1 min"
    for            = "1m"
    condition      = "C"
    no_data_state  = "Alerting"
    exec_err_state = "Error"

    data {
      ref_id         = "A"
      datasource_uid = data.grafana_data_source.prometheus.uid
      relative_time_range {
        from = 60
        to   = 0
      }
      model = jsonencode({
        editorMode = "code"
        expr       = "sum(kube_deployment_status_replicas_ready{deployment=\"aegis-greeter\"})"
        intervalMs = 1000
        instant    = true
        refId      = "A"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        type       = "threshold"
        refId      = "C"
        expression = "A"
        conditions = [{
          type      = "query"
          evaluator = { type = "lt", params = [1] }
          operator  = { type = "and" }
          query     = { params = ["A"] }
        }]
      })
    }

    annotations = {
      summary          = "aegis-greeter Deployment has 0 ready pods"
      __dashboardUid__ = grafana_dashboard.greeter_overview.uid
      __panelId__      = "6"
    }
    labels = {
      severity = "critical"
    }
  }
}

resource "grafana_rule_group" "memory_near_limit" {
  name             = "memory-near-limit"
  folder_uid       = grafana_folder.aegis_stateless.uid
  interval_seconds = 60

  rule {
    name           = "container memory > 90% of limit over 5 min"
    for            = "5m"
    condition      = "C"
    no_data_state  = "NoData"
    exec_err_state = "Error"

    data {
      ref_id         = "A"
      datasource_uid = data.grafana_data_source.prometheus.uid
      relative_time_range {
        from = 300
        to   = 0
      }
      model = jsonencode({
        editorMode = "code"
        expr       = "max(container_memory_working_set_bytes{pod=~\"aegis-greeter.*\"}) / max(kube_pod_container_resource_limits{pod=~\"aegis-greeter.*\",resource=\"memory\"})"
        intervalMs = 1000
        instant    = true
        refId      = "A"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        type       = "threshold"
        refId      = "C"
        expression = "A"
        conditions = [{
          type      = "query"
          evaluator = { type = "gt", params = [0.9] }
          operator  = { type = "and" }
          query     = { params = ["A"] }
        }]
      })
    }

    annotations = {
      summary          = "aegis-greeter container memory exceeded 90% of limit over 5 min — OOMKill imminent"
      __dashboardUid__ = grafana_dashboard.greeter_overview.uid
      __panelId__      = "7"
    }
    labels = {
      severity = "warning"
    }
  }
}

resource "grafana_rule_group" "node_memory_pressure" {
  name             = "node-memory-pressure"
  folder_uid       = grafana_folder.aegis_stateless.uid
  interval_seconds = 60

  rule {
    name           = "node memory utilization > 85% over 5 min"
    for            = "5m"
    condition      = "C"
    no_data_state  = "NoData"
    exec_err_state = "Error"

    data {
      ref_id         = "A"
      datasource_uid = data.grafana_data_source.prometheus.uid
      relative_time_range {
        from = 300
        to   = 0
      }
      model = jsonencode({
        editorMode = "code"
        expr       = "max(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)"
        intervalMs = 1000
        instant    = true
        refId      = "A"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        type       = "threshold"
        refId      = "C"
        expression = "A"
        conditions = [{
          type      = "query"
          evaluator = { type = "gt", params = [0.85] }
          operator  = { type = "and" }
          query     = { params = ["A"] }
        }]
      })
    }

    annotations = {
      summary          = "an aegis-stateless node exceeded 85% memory utilization over 5 min"
      __dashboardUid__ = grafana_dashboard.greeter_overview.uid
      __panelId__      = "9"
    }
    labels = {
      severity = "warning"
    }
  }
}

resource "grafana_rule_group" "apiserver_error_rate" {
  name             = "apiserver-error-rate"
  folder_uid       = grafana_folder.aegis_stateless.uid
  interval_seconds = 60

  rule {
    name           = "EKS apiserver 5xx rate > 5% over 5 min"
    for            = "5m"
    condition      = "C"
    no_data_state  = "NoData"
    exec_err_state = "Error"

    data {
      ref_id         = "A"
      datasource_uid = data.grafana_data_source.prometheus.uid
      relative_time_range {
        from = 300
        to   = 0
      }
      model = jsonencode({
        editorMode = "code"
        expr       = "sum(rate(apiserver_request_total{code=~\"5..\"}[5m])) / clamp_min(sum(rate(apiserver_request_total[5m])), 1e-9)"
        intervalMs = 1000
        instant    = true
        refId      = "A"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        type       = "threshold"
        refId      = "C"
        expression = "A"
        conditions = [{
          type      = "query"
          evaluator = { type = "gt", params = [0.05] }
          operator  = { type = "and" }
          query     = { params = ["A"] }
        }]
      })
    }

    annotations = {
      summary          = "EKS apiserver 5xx rate exceeded 5% over 5 min — control-plane degradation"
      __dashboardUid__ = grafana_dashboard.greeter_overview.uid
      __panelId__      = "11"
    }
    labels = {
      severity = "critical"
    }
  }
}
