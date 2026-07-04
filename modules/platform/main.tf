###############################################################################
# Platform composition — one call that stands up a complete EKS environment
# by wiring together the in-house building-block modules:
#   kms -> vpc -> eks -> eks-addons (IRSA) -> ecr
###############################################################################

locals {
  cluster_name = "${var.name_prefix}-eks"
  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Cluster     = local.cluster_name
  })
}

module "kms" {
  source                  = "../kms"
  name_prefix             = var.name_prefix
  aws_region              = var.aws_region
  deletion_window_in_days = var.kms_deletion_window_in_days
  tags                    = local.tags
}

module "vpc" {
  source       = "../vpc"
  name_prefix  = var.name_prefix
  cluster_name = local.cluster_name

  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  intra_subnet_cidrs   = var.intra_subnet_cidrs

  enable_nat_gateway = true
  single_nat_gateway = var.single_nat_gateway

  flow_log_retention_days = var.log_retention_days
  logs_kms_key_arn        = module.kms.logs_key_arn

  tags = local.tags
}

module "eks" {
  source = "../eks"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets
  intra_subnet_ids   = module.vpc.intra_subnets

  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  eks_kms_key_arn  = module.kms.eks_key_arn
  ebs_kms_key_arn  = module.kms.ebs_key_arn
  logs_kms_key_arn = module.kms.logs_key_arn

  control_plane_log_retention_days = var.log_retention_days
  default_instance_types           = var.default_instance_types
  node_disk_size                   = var.node_disk_size
  permissions_boundary_arn         = var.permissions_boundary_arn

  managed_node_groups = var.managed_node_groups
  access_entries      = var.access_entries

  tags = local.tags
}

module "eks_addons" {
  source = "../eks-addons"

  cluster_name      = module.eks.cluster_name
  aws_region        = var.aws_region
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  permissions_boundary_arn        = var.permissions_boundary_arn
  enable_load_balancer_controller = var.enable_load_balancer_controller
  enable_external_dns             = var.enable_external_dns
  external_dns_hosted_zone_arns   = var.external_dns_hosted_zone_arns
  enable_karpenter                = var.enable_karpenter

  tags = local.tags
}

module "ecr" {
  source           = "../ecr"
  repository_names = var.ecr_repository_names
  kms_key_arn      = module.kms.ebs_key_arn
  tags             = local.tags
}
