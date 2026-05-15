# Pattern X — single source of truth for the multi-region topology.
#
# Read by terraform/envs/platform/ and terraform/envs/regional/ via the Makefile
# (-var-file=$(ROOT)/regions.auto.tfvars). Every region-aware resource uses
# for_each = var.regions:
#
#   - provider "aws" alias generation
#   - module "regional_stack" instantiation
#   - aws_route53_record / aws_route53_health_check
#   - ECR replication rule destinations (source region excluded)
#
# Adding a region:
#   1. Uncomment (or add) an entry below.
#   2. make platform regional
#   3. Done. No .tf file edits, no new directories.

regions = {
  "eu-central-1" = {
    cidr          = "10.10.0.0/16"
    node_instance = "t3.medium"
    node_min      = 2
    node_max      = 4
  }

  # Secondary region — architecture is multi-region-ready, deployment is
  # single-region for take-home scope (per locked decision "Multi-region
  # designed, single-region deployed"). Uncomment + apply to activate.
  #
  # "eu-west-1" = {
  #   cidr          = "10.20.0.0/16"
  #   node_instance = "t3.medium"
  #   node_min      = 2
  #   node_max      = 4
  # }
}
