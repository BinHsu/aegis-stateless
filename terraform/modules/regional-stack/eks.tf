module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.20"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access = true
  enable_irsa                    = true

  # All 5 control-plane log types → CloudWatch (audit / forensics
  # side-effect; never dashboarded). Per AS-0028 (revised) — CW retained
  # for audit only.
  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # Managed node group on Spot — significant cost reduction; acceptable for
  # take-home + stateless workload (greeter has no in-flight session state).
  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = [var.node_instance]
      capacity_type  = "SPOT"

      min_size     = var.node_min
      max_size     = var.node_max
      desired_size = var.node_min
    }
  }

  # Cluster-creator gets system:masters via the EKS API authenticator
  # by default in this module — no aws-auth ConfigMap juggling.
  enable_cluster_creator_admin_permissions = true

  tags = local.common_tags
}
