# Grafana Cloud credentials stored in SSM Parameter Store under a single
# prefix `/aegis/grafana-cloud/`. The regional/ env's Alloy IRSA role is
# scoped to ssm:GetParameter on exactly this prefix (least privilege).
#
# Token + remote_write username are SecureString (KMS-encrypted at rest).
# Endpoint URLs are plain String (not secret).

resource "aws_ssm_parameter" "gc_api_token" {
  name        = "/aegis/grafana-cloud/api-token"
  description = "Grafana Cloud API token with admin scope on the aegis stack."
  type        = "SecureString"
  value       = var.grafana_cloud_api_token
}

resource "aws_ssm_parameter" "gc_remote_write_username" {
  name        = "/aegis/grafana-cloud/remote-write-username"
  description = "Grafana Cloud remote_write user ID (typically GC stack ID, shared across Mimir/Loki/Tempo/Pyroscope)."
  type        = "SecureString"
  value       = var.grafana_cloud_remote_write_username
}

resource "aws_ssm_parameter" "gc_mimir_url" {
  name        = "/aegis/grafana-cloud/mimir-url"
  description = "Mimir remote_write endpoint."
  type        = "String"
  value       = var.grafana_cloud_mimir_url
}

resource "aws_ssm_parameter" "gc_loki_url" {
  name        = "/aegis/grafana-cloud/loki-url"
  description = "Loki push endpoint."
  type        = "String"
  value       = var.grafana_cloud_loki_url
}

resource "aws_ssm_parameter" "gc_tempo_url" {
  name        = "/aegis/grafana-cloud/tempo-url"
  description = "Tempo OTLP endpoint."
  type        = "String"
  value       = var.grafana_cloud_tempo_url
}

resource "aws_ssm_parameter" "gc_pyroscope_url" {
  name        = "/aegis/grafana-cloud/pyroscope-url"
  description = "Pyroscope ingest endpoint."
  type        = "String"
  value       = var.grafana_cloud_pyroscope_url
}
