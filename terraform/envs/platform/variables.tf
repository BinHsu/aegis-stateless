# ---- Pattern X: regions (read from repo-root regions.auto.tfvars.json) ----
variable "regions" {
  description = "Multi-region topology — single source of truth at repo-root regions.auto.tfvars.json. Platform reads it for ECR replication targeting (only enabled entries are real destinations)."
  type = map(object({
    enabled       = bool
    cidr          = string
    node_instance = string
    node_min      = number
    node_max      = number
  }))
}

# ---- platform basics -------------------------------------------------------
variable "platform_region" {
  description = "AWS region where this platform env applies provider operations. Route 53 is global; ECR + S3 etc. live in this region as their 'source' region. Sourced from regions.auto.tfvars.json top-level (single source of truth)."
  type        = string
}

variable "dns_zone_name" {
  description = "DNS zone name for the Route 53 hosted zone. Placeholder domain — no real domain is registered for the take-home; DNS is demonstrated via 'dig @<our-ns>'."
  type        = string
  default     = "aegis-stateless.example.com"
}

variable "ecr_repository_name" {
  description = "Name of the ECR repo where aegis-greeter pushes container images."
  type        = string
  default     = "aegis-greeter"
}

# ---- Grafana Cloud creds (sensitive; supplied via gitignored tfvars) -------
variable "grafana_cloud_url" {
  description = "Grafana Cloud stack URL (e.g. https://aegis.grafana.net). Used by the grafana TF provider."
  type        = string
  default     = "https://aegis.grafana.net"
}

variable "grafana_cloud_api_token" {
  description = "Grafana Cloud Access Policy token (glc_…) — used as the Alloy remote_write password for Mimir/Loki/Tempo/Pyroscope. NOT the grafana-provider auth (see grafana_auth_token). Supply via gitignored secrets.auto.tfvars. NEVER commit a value."
  type        = string
  sensitive   = true
}

variable "grafana_auth_token" {
  description = "Grafana instance service-account token (glsa_…) — auth for the `grafana` TF provider managing dashboards/folders/alert-rules on aegis.grafana.net. Distinct from grafana_cloud_api_token. Create via the instance: Administration → Users and access → Service accounts → Admin role → add token. NEVER commit a value."
  type        = string
  sensitive   = true
}

# Grafana Cloud uses a distinct instance-ID username per backend (Mimir,
# Loki, Tempo, Pyroscope each differ); only the API token is shared.
variable "grafana_cloud_mimir_username" {
  description = "Mimir remote_write username (GC Prometheus instance ID)."
  type        = string
  sensitive   = true
}

variable "grafana_cloud_loki_username" {
  description = "Loki push username (GC Loki instance ID)."
  type        = string
  sensitive   = true
}

variable "grafana_cloud_tempo_username" {
  description = "Tempo OTLP username (GC Tempo instance ID)."
  type        = string
  sensitive   = true
}

variable "grafana_cloud_pyroscope_username" {
  description = "Pyroscope username (GC Pyroscope instance ID)."
  type        = string
  sensitive   = true
}

variable "grafana_cloud_mimir_url" {
  description = "Mimir push URL (e.g. https://prometheus-prod-XX-prod-eu-west-2.grafana.net/api/prom/push)."
  type        = string
  sensitive   = true
}

variable "grafana_cloud_loki_url" {
  description = "Loki push URL (e.g. https://logs-prod-XXX.grafana.net/loki/api/v1/push)."
  type        = string
  sensitive   = true
}

variable "grafana_cloud_tempo_url" {
  description = "Tempo OTLP URL (e.g. https://tempo-prod-XX-prod-eu-west-2.grafana.net:443)."
  type        = string
  sensitive   = true
}

variable "grafana_cloud_pyroscope_url" {
  description = "Pyroscope ingest URL (e.g. https://profiles-prod-XXX.grafana.net)."
  type        = string
  sensitive   = true
}

# ---- Budget alarm ----------------------------------------------------------
variable "budget_alert_email" {
  description = "Email to receive AWS Budget alarms. Supply via gitignored secrets.auto.tfvars. NEVER commit a value (per anonymization policy)."
  type        = string
  sensitive   = true
}

variable "budget_warn_amount_usd" {
  description = "Warning threshold (USD) — 80% of this triggers a notification."
  type        = number
  default     = 10
}

variable "budget_hard_amount_usd" {
  description = "Hard threshold (USD) — 100% of this triggers a notification."
  type        = number
  default     = 25
}

# ---- GitHub OIDC -----------------------------------------------------------
variable "github_owner" {
  description = "GitHub org/user that owns the aegis-greeter + aegis-stateless repos. Used for the github TF provider + OIDC trust policies."
  type        = string
  default     = "BinHsu"
}

variable "github_token" {
  description = "GitHub PAT for the github TF provider. Needs admin:public_key for deploy key registration (regional-stack consumes this output via remote_state)."
  type        = string
  sensitive   = true
}

# ---- tags ------------------------------------------------------------------
variable "project_tag" {
  description = "Value of the Project tag applied to all resources."
  type        = string
  default     = "aegis-stateless"
}

variable "cost_center_tag" {
  description = "Value of the CostCenter tag applied to all resources."
  type        = string
  default     = "platform-take-home"
}
