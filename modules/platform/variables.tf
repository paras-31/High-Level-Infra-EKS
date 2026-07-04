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

# --- EKS -------------------------------------------------------------------- #
variable "cluster_version" {
  description = "Kubernetes version."
  type        = string
  default     = "1.31"
}

variable "cluster_endpoint_public_access" {
  description = "Enable the public API endpoint."
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to the public API endpoint."
  type        = list(string)
  default     = []
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
