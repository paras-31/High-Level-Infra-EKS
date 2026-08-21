###############################################################################
# Platform — EKS stack only. VPC comes from external High-level-VPC git repo.
#
#   kms  →  High-level-VPC (git, you pass subnet/NAT/NACL values)
#        →  network-eks (EKS tags, intra subnets, endpoints, flow logs)
#        →  eks → eks-addons → ecr
###############################################################################

locals {
  cluster_name = "${var.name_prefix}-eks"
  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Cluster     = local.cluster_name
  })

  # API: private endpoint always; public endpoint only when admin IPs are set (CIDR-locked).
  eks_public_api_enabled = length(var.admin_access_cidrs) > 0
  eks_public_api_cidrs   = var.admin_access_cidrs
}

module "kms" {
  source                  = "../kms"
  name_prefix             = var.name_prefix
  aws_region              = var.aws_region
  deletion_window_in_days = var.kms_deletion_window_in_days
  tags                    = local.tags
}

# ── VPC: external private repo — pass only the values you need ────────────────
# CI checks out High-level-VPC to .terraform-modules/ before terraform init.
# Local: run scripts/fetch-vpc-module.sh once (or clone manually to that path).
module "vpc" {
  source = "../../.terraform-modules/High-level-VPC/modules/vpc"

  name_prefix = var.name_prefix
  vpc_cidr    = var.vpc_cidr
  azs         = var.azs

  enable_public_subnets  = var.vpc_enable_public_subnets
  enable_private_subnets = var.vpc_enable_private_subnets
  public_subnet_cidrs    = var.public_subnet_cidrs
  private_subnet_cidrs   = var.private_subnet_cidrs

  enable_nat_gateway = var.vpc_enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway
  enable_nacl        = var.vpc_enable_nacl

  # The shared vpc-nacl module's default private ruleset only allows inbound
  # from the VPC CIDR. NACLs are stateless, so return traffic from outside the
  # VPC (S3 gateway endpoint / NAT) lands on ephemeral ports and is dropped by
  # the implicit deny. That breaks ECR image-layer pulls from the regional
  # starport S3 bucket (nodes -> ImagePullBackOff -> CNI never starts ->
  # nodes NotReady -> nodegroup stuck CREATING). Override the private rules to
  # add the missing inbound ephemeral-return allow (the public NACL already
  # has this).
  private_nacl_rules = [
    {
      rule_number = 100
      egress      = false
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      cidr_block  = var.vpc_cidr
      action      = "allow"
    },
    {
      rule_number = 120
      egress      = false
      protocol    = "tcp"
      from_port   = 1024
      to_port     = 65535
      cidr_block  = "0.0.0.0/0"
      action      = "allow"
    },
    {
      rule_number = 100
      egress      = true
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      cidr_block  = "0.0.0.0/0"
      action      = "allow"
    },
  ]

  tags = local.tags
}

# ── EKS-only network extras (not in High-level-VPC) ─────────────────────────
module "network_eks" {
  source = "../network-eks"

  name_prefix             = var.name_prefix
  vpc_id                  = module.vpc.vpc_id
  vpc_cidr_block          = module.vpc.vpc_cidr_block
  cluster_name            = local.cluster_name
  azs                     = var.azs
  public_subnet_ids       = module.vpc.public_subnet_ids
  private_subnet_ids      = module.vpc.private_subnet_ids
  private_route_table_ids = module.vpc.private_route_table_ids
  intra_subnet_cidrs      = var.intra_subnet_cidrs
  enable_flow_logs        = var.enable_flow_logs
  flow_log_retention_days = var.log_retention_days
  logs_kms_key_arn        = module.kms.logs_key_arn
  enable_vpc_endpoints    = var.enable_vpc_endpoints
  interface_endpoints     = var.interface_endpoints
  tags                    = local.tags

  depends_on = [module.vpc]
}

module "eks" {
  source = "../eks"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  intra_subnet_ids   = module.network_eks.intra_subnet_ids

  # Private API inside VPC + optional public API locked to admin_access_cidrs only
  cluster_endpoint_public_access       = local.eks_public_api_enabled
  cluster_endpoint_public_access_cidrs = local.eks_public_api_cidrs

  eks_kms_key_arn  = module.kms.eks_key_arn
  ebs_kms_key_arn  = module.kms.ebs_key_arn
  logs_kms_key_arn = module.kms.logs_key_arn

  control_plane_log_retention_days = var.log_retention_days
  default_instance_types           = var.default_instance_types
  node_disk_size                   = var.node_disk_size
  permissions_boundary_arn         = var.permissions_boundary_arn

  managed_node_groups = var.managed_node_groups
  access_entries      = var.access_entries

  vpc_endpoint_ids      = module.network_eks.vpc_endpoint_ids
  network_ready_trigger = module.network_eks.network_ready

  tags = local.tags

  # ECR/S3/STS VPC endpoints must exist before nodes pull addon images (602401143452.dkr.ecr.*).
  depends_on = [module.network_eks]
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
