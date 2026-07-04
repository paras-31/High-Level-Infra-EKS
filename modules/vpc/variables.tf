variable "name_prefix" {
  description = "Prefix for VPC resource names, e.g. eks-prod."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name (used for subnet discovery tags)."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private (node/pod) subnets — one per AZ."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public (load balancer) subnets — one per AZ."
  type        = list(string)
}

variable "intra_subnet_cidrs" {
  description = "CIDRs for intra subnets (no internet route) — control plane ENIs, etc."
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "Provision NAT gateway(s) so private subnets can egress to the internet."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single shared NAT gateway (cheaper, non-HA). Set false in prod."
  type        = bool
  default     = false
}

variable "flow_log_retention_days" {
  description = "Retention in days for VPC flow logs."
  type        = number
  default     = 90
}

variable "logs_kms_key_arn" {
  description = "KMS key ARN used to encrypt the flow-log CloudWatch group."
  type        = string
  default     = null
}

variable "interface_endpoints" {
  description = "AWS services to expose via interface VPC endpoints."
  type        = list(string)
  default     = ["ecr.api", "ecr.dkr", "ec2", "sts", "logs", "elasticloadbalancing", "autoscaling"]
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
