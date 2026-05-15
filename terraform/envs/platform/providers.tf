provider "aws" {
  region = var.platform_region

  default_tags {
    tags = {
      Project    = var.project_tag
      Env        = "platform"
      ManagedBy  = "terraform"
      Repo       = "github.com/BinHsu/aegis-stateless"
      CostCenter = var.cost_center_tag
    }
  }
}

provider "grafana" {
  url  = var.grafana_cloud_url
  auth = var.grafana_cloud_api_token
}

provider "github" {
  owner = var.github_owner
  token = var.github_token
}
