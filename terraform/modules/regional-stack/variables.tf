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

variable "ecr_url" {
  description = "ECR repository URL (from platform/) — referenced by k8s manifests / image-tag bumps from sibling CI."
  type        = string
}

variable "zone_id" {
  description = "Route 53 hosted zone ID (from platform/). Not used directly here — exported so regional/ can build alias records."
  type        = string
}

variable "zone_name" {
  description = "Route 53 hosted zone name (from platform/)."
  type        = string
}

variable "alb_logs_bucket" {
  description = "S3 bucket for ALB access logs (in platform/). ALB Ingress access_logs annotation points at this bucket with region-prefixed key."
  type        = string
}

variable "repo_url_https" {
  description = "HTTPS URL of aegis-stateless (used by ArgoCD Application CR source.repoURL via the SSH-aliased secret)."
  type        = string
}

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

variable "gc_remote_write_username" {
  description = "Grafana Cloud remote_write user ID (typically stack ID, shared across Mimir/Loki/Tempo/Pyroscope)."
  type        = string
  sensitive   = true
}

variable "gc_mimir_url" {
  description = "Mimir remote_write endpoint."
  type        = string
  sensitive   = true
}

variable "gc_loki_url" {
  description = "Loki push endpoint."
  type        = string
  sensitive   = true
}

variable "gc_tempo_url" {
  description = "Tempo OTLP endpoint."
  type        = string
  sensitive   = true
}

variable "gc_pyroscope_url" {
  description = "Pyroscope ingest endpoint."
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
