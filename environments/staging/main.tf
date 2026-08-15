###############################################################################
# STAGING environment — prod-like (private, HA-ish) for pre-prod validation
###############################################################################

locals {
  name_prefix = "eks-staging"
  tags = {
    Project     = "eks-platform"
    Environment = "staging"
    CostCenter  = "platform"
  }

  access_entries = var.platform_admin_role_arn == null ? {} : {
    platform_admins = {
      principal_arn = var.platform_admin_role_arn
      policy_associations = [{
        policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope = { type = "cluster" }
      }]
    }
  }
}

module "platform" {
  source = "../../modules/platform"

  name_prefix = local.name_prefix
  environment = "staging"
  aws_region  = var.aws_region

  admin_access_cidrs = var.admin_access_cidrs

  vpc_cidr             = "10.20.0.0/16"
  azs                  = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
  private_subnet_cidrs = ["10.20.0.0/20", "10.20.16.0/20", "10.20.32.0/20"]
  public_subnet_cidrs  = ["10.20.48.0/24", "10.20.49.0/24", "10.20.50.0/24"]
  intra_subnet_cidrs   = ["10.20.60.0/24", "10.20.61.0/24", "10.20.62.0/24"]
  single_nat_gateway   = true

  log_retention_days = 90

  managed_node_groups = {
    system = {
      desired_size   = 2
      min_size       = 2
      max_size       = 4
      instance_types = ["m6i.large"]
      labels         = { role = "system" }
    }
  }

  access_entries       = local.access_entries
  ecr_repository_names = ["frontend", "backend"]

  enable_load_balancer_controller = true
  enable_external_dns             = true
  enable_karpenter                = true

  tags = local.tags
}
