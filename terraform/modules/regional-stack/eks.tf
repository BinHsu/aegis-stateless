module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

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

  # Cluster-creator (the IAM principal running `make` locally) gets
  # cluster-admin via the EKS access-entry API — no aws-auth ConfigMap.
  enable_cluster_creator_admin_permissions = true

  # The CI roles need cluster access too: `terraform plan`/`apply` for the
  # regional env reads Helm release state (stored in K8s Secrets) and the
  # kubernetes_* resources. Both roles get a ClusterAdmin access entry —
  # the AWS-side trust scoping (ci = read-only AWS / any ref; apply =
  # admin AWS / refs/heads/main only) is the real blast-radius boundary;
  # a `terraform plan` run by the ci role is non-mutating regardless of
  # its K8s rights. Least-privilege K8s RBAC for a terraform-with-Helm
  # plan (Helm state lives in Secrets, which the EKS View policy cannot
  # read) would be a bespoke role — deferred, see docs/tradeoffs.md.
  access_entries = {
    infra_ci = {
      principal_arn = var.ci_role_arn
      policy_associations = {
        cluster_admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
    infra_apply = {
      principal_arn = var.apply_role_arn
      policy_associations = {
        cluster_admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  tags = local.common_tags
}
