###############################################################################
# DEV environment — cost-optimized (single NAT), smaller nodes, no governance
###############################################################################

locals {
  name_prefix = "eks-dev"
  tags = {
    Project     = "eks-platform"
    Environment = "dev"
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
  environment = "dev"
  aws_region  = var.aws_region

  admin_access_cidrs = var.admin_access_cidrs

  # --- Networking (cost: single shared NAT) -------------------------------- #
  vpc_cidr             = "10.10.0.0/16"
  azs                  = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
  private_subnet_cidrs = ["10.10.0.0/20", "10.10.16.0/20", "10.10.32.0/20"]
  public_subnet_cidrs  = ["10.10.48.0/24", "10.10.49.0/24", "10.10.50.0/24"]
  intra_subnet_cidrs   = ["10.10.60.0/24", "10.10.61.0/24", "10.10.62.0/24"]
  single_nat_gateway = true

  log_retention_days = 30

  managed_node_groups = {
    default = {
      desired_size   = 2
      min_size       = 1
      max_size       = 4
      instance_types = ["t3.large"]
      capacity_type  = "SPOT"
      labels         = { role = "default" }
    }
  }

  access_entries       = local.access_entries
  ecr_repository_names = ["frontend", "backend"]

  enable_load_balancer_controller = true
  enable_external_dns             = true
  enable_karpenter                = true

  tags = local.tags
}
