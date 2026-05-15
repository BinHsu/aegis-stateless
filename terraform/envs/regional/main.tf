# Single module instance — one per regional apply. Makefile/CI iterates
# over enabled regions in regions.auto.tfvars.json, invoking this env
# once per region with that region's scalars.

module "stack" {
  source = "../../modules/regional-stack"

  providers = {
    aws        = aws
    kubernetes = kubernetes
    helm       = helm
    github     = github
  }

  region        = var.region
  vpc_cidr      = var.vpc_cidr
  node_instance = var.node_instance
  node_min      = var.node_min
  node_max      = var.node_max

  repo_url_ssh = var.repo_url_ssh
  repo_name    = var.repo_name

  gc_api_token             = data.aws_ssm_parameter.gc_api_token.value
  gc_remote_write_username = data.aws_ssm_parameter.gc_remote_write_username.value
  gc_mimir_url             = data.aws_ssm_parameter.gc_mimir_url.value
  gc_loki_url              = data.aws_ssm_parameter.gc_loki_url.value
  gc_tempo_url             = data.aws_ssm_parameter.gc_tempo_url.value
  gc_pyroscope_url         = data.aws_ssm_parameter.gc_pyroscope_url.value

  project_tag     = var.project_tag
  cost_center_tag = var.cost_center_tag
}

# Route 53 records / health checks: deferred to external-dns (installed
# inside each cluster's regional-stack module). external-dns watches
# Ingresses with `external-dns.alpha.kubernetes.io/hostname` annotation
# and reconciles the Route 53 record set under the platform-owned zone.
# Pattern X data flow stays clean: which regions get records = which
# clusters exist = which regions are enabled in regions.auto.tfvars.json.
