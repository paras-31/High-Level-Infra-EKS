###############################################################################
# PROD environment — HA, private, full governance
###############################################################################

locals {
  name_prefix = "eks-prod"
  tags = {
    Project     = "eks-platform"
    Environment = "prod"
    CostCenter  = "platform"
  }

  # Grant cluster-admin to the platform admin role (if provided).
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
  environment = "prod"
  aws_region  = var.aws_region

  # --- Networking (HA: one NAT per AZ) ------------------------------------- #
  vpc_cidr             = "10.30.0.0/16"
  azs                  = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnet_cidrs = ["10.30.0.0/20", "10.30.16.0/20", "10.30.32.0/20"]
  public_subnet_cidrs  = ["10.30.48.0/24", "10.30.49.0/24", "10.30.50.0/24"]
  intra_subnet_cidrs   = ["10.30.60.0/24", "10.30.61.0/24", "10.30.62.0/24"]
  single_nat_gateway   = false

  # --- Cluster (fully private endpoint) ------------------------------------ #
  cluster_version                = "1.31"
  cluster_endpoint_public_access = false
  log_retention_days             = 365

  managed_node_groups = {
    system = {
      desired_size   = 3
      min_size       = 3
      max_size       = 6
      instance_types = ["m6i.large"]
      labels         = { role = "system" }
      taints = [{
        key    = "CriticalAddonsOnly"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
    }
    # App workloads primarily scale via Karpenter; this baseline pool is small.
    apps = {
      desired_size   = 2
      min_size       = 2
      max_size       = 10
      instance_types = ["m6i.xlarge"]
      labels         = { role = "apps" }
    }
  }

  access_entries = local.access_entries

  ecr_repository_names = ["frontend", "backend"]

  enable_load_balancer_controller = true
  enable_external_dns             = true
  enable_karpenter                = true

  tags = local.tags
}

# --- Account-level governance (deployed here, once) ------------------------- #
module "security_baseline" {
  source = "../../modules/security-baseline"

  name_prefix        = local.name_prefix
  log_bucket_name    = var.security_log_bucket_name
  logs_kms_key_arn   = module.platform.kms_key_arns["logs"]
  log_retention_days = 365

  enable_cloudtrail   = true
  enable_guardduty    = true
  enable_security_hub = true
  enable_config       = true

  tags = local.tags
}
