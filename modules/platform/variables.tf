variable "name_prefix" {
  description = "Prefix for all resources, e.g. eks-prod. Cluster becomes <prefix>-eks."
  type        = string
}

variable "environment" {
  description = "Environment name (dev/staging/prod)."
  type        = string
}

variable "aws_region" {
  description = "AWS region."
  type        = string
}

# --- Networking ------------------------------------------------------------- #
variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
}

variable "azs" {
  description = "Availability zones."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs (one per AZ)."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs (one per AZ)."
  type        = list(string)
}

variable "intra_subnet_cidrs" {
  description = "Intra subnet CIDRs (one per AZ)."
  type        = list(string)
  default     = []
}

variable "single_nat_gateway" {
  description = "Single shared NAT (cheaper). false in prod."
  type        = bool
  default     = false
}

# --- VPC (external High-level-VPC git module) ------------------------------- #
# Git ref is pinned in main.tf module "vpc" source (Terraform requires a static URL).

variable "vpc_enable_public_subnets" {
  description = "Public subnets for NAT placement and external LBs (not public EKS API)."
  type        = bool
  default     = true
}

variable "vpc_enable_private_subnets" {
  description = "Private subnets for EKS nodes."
  type        = bool
  default     = true
}

variable "vpc_enable_nat_gateway" {
  description = "NAT for private subnet egress."
  type        = bool
  default     = true
}

variable "vpc_enable_nacl" {
  description = "Subnet NACLs (defense in depth)."
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Send VPC flow logs to encrypted CloudWatch."
  type        = bool
  default     = true
}

variable "enable_vpc_endpoints" {
  description = "Create VPC endpoints so nodes reach AWS APIs without public internet."
  type        = bool
  default     = true
}

variable "interface_endpoints" {
  description = "AWS services exposed via interface VPC endpoints."
  type        = list(string)
  default     = ["ecr.api", "ecr.dkr", "ec2", "sts", "logs", "elasticloadbalancing", "autoscaling", "eks"]
}

# --- EKS (private API enforced in platform/main.tf) ------------------------- #
variable "admin_access_cidrs" {
  description = <<-EOT
    Admin IP(s) allowed to reach the EKS public API endpoint, as /32 CIDRs
    (e.g. ["134.238.10.24/32"]). Nodes stay in private subnets — never exposed.
    Set empty [] for fully private API (VPC/VPN/bastion access only).
  EOT
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.admin_access_cidrs :
      !contains(["0.0.0.0/0", "::/0"], cidr)
    ])
    error_message = "admin_access_cidrs must not contain 0.0.0.0/0 or ::/0."
  }
}

variable "cluster_version" {
  description = "Kubernetes version."
  type        = string
  default     = "1.31"
}

variable "default_instance_types" {
  description = "Default node instance types."
  type        = list(string)
  default     = ["m6i.large"]
}

variable "node_disk_size" {
  description = "Node root disk size (GiB)."
  type        = number
  default     = 50
}

variable "managed_node_groups" {
  description = "EKS managed node group definitions (see eks module)."
  type        = any
  default     = {}
}

variable "access_entries" {
  description = "EKS access entries (see eks module)."
  type        = any
  default     = {}
}

variable "permissions_boundary_arn" {
  description = "Optional permissions boundary applied to created IAM roles."
  type        = string
  default     = null
}

# --- Add-ons ---------------------------------------------------------------- #
variable "enable_load_balancer_controller" {
  description = "Create IRSA for the AWS Load Balancer Controller."
  type        = bool
  default     = true
}

variable "enable_external_dns" {
  description = "Create IRSA for external-dns."
  type        = bool
  default     = true
}

variable "external_dns_hosted_zone_arns" {
  description = "Route53 hosted zone ARNs external-dns may modify."
  type        = list(string)
  default     = ["*"]
}

variable "enable_karpenter" {
  description = "Create Karpenter IRSA + node role + interruption queue."
  type        = bool
  default     = true
}

# --- KMS / logging ---------------------------------------------------------- #
variable "kms_deletion_window_in_days" {
  description = "KMS key deletion window."
  type        = number
  default     = 30
}

variable "log_retention_days" {
  description = "Retention (days) for flow logs and control-plane logs."
  type        = number
  default     = 90
}

# --- ECR -------------------------------------------------------------------- #
variable "ecr_repository_names" {
  description = "ECR repositories to create for this environment."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
