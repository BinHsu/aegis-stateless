variable "region" {
  description = "AWS region this stack instance runs in. Used in resource names, IRSA-trusted role names, ArgoCD deploy-key title, alloy resource prefix."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block. Provisioned across 3 AZs with public+private subnets."
  type        = string
}

variable "node_instance" {
  description = "EC2 instance type for the EKS managed node group."
  type        = string
  default     = "t3.medium"
}

variable "node_min" {
  description = "Minimum node count for the managed node group."
  type        = number
}

variable "node_max" {
  description = "Maximum node count for the managed node group."
  type        = number
}

# NOTE: ecr_url / zone_id / zone_name / alb_logs_bucket / repo_url_https
# are intentionally NOT module inputs — nothing in this module consumes
# them. The greeter image reference is set in k8s/overlays/prod (kustomize),
# Route 53 records are deferred to external-dns, and ArgoCD authenticates
# via the SSH repo URL. Re-add here only when a consumer actually exists.

variable "repo_url_ssh" {
  description = "SSH URL of aegis-stateless (referenced by the ArgoCD repository Secret data.url)."
  type        = string
}

variable "repo_name" {
  description = "Bare repo name (passed to github_repository_deploy_key for deploy-key registration)."
  type        = string
}

# ---- Grafana Cloud creds (sensitive) -------------------------------------
variable "gc_api_token" {
  description = "Grafana Cloud API token (admin on the aegis stack). Embedded in a K8s Secret used by Alloy."
  type        = string
  sensitive   = true
}

variable "gc_mimir_url" {
  description = "Mimir remote_write endpoint."
  type        = string
  sensitive   = true
}

variable "gc_mimir_username" {
  description = "Mimir remote_write username (GC Prometheus instance ID)."
  type        = string
  sensitive   = true
}

variable "gc_loki_url" {
  description = "Loki push endpoint."
  type        = string
  sensitive   = true
}

variable "gc_loki_username" {
  description = "Loki push username (GC Loki instance ID)."
  type        = string
  sensitive   = true
}

variable "gc_tempo_url" {
  description = "Tempo OTLP endpoint."
  type        = string
  sensitive   = true
}

variable "gc_tempo_username" {
  description = "Tempo OTLP username (GC Tempo instance ID)."
  type        = string
  sensitive   = true
}

variable "gc_pyroscope_url" {
  description = "Pyroscope ingest endpoint."
  type        = string
  sensitive   = true
}

variable "gc_pyroscope_username" {
  description = "Pyroscope username (GC Pyroscope instance ID)."
  type        = string
  sensitive   = true
}

# ---- tags -----------------------------------------------------------------
variable "project_tag" {
  description = "Project tag value."
  type        = string
}

variable "cost_center_tag" {
  description = "CostCenter tag value."
  type        = string
}

variable "cluster_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.30"
}
