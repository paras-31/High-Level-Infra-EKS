variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "aws_region" {
  description = "AWS region."
  type        = string
}

variable "oidc_provider_arn" {
  description = "IAM OIDC provider ARN from the eks module."
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC provider URL (no scheme) from the eks module."
  type        = string
}

variable "permissions_boundary_arn" {
  description = "Optional permissions boundary for controller IAM roles."
  type        = string
  default     = null
}

variable "enable_load_balancer_controller" {
  description = "Create IRSA role for the AWS Load Balancer Controller."
  type        = bool
  default     = true
}

variable "enable_external_dns" {
  description = "Create IRSA role for external-dns."
  type        = bool
  default     = true
}

variable "external_dns_hosted_zone_arns" {
  description = "Route53 hosted zone ARNs external-dns may modify. ['*'] allows all."
  type        = list(string)
  default     = ["*"]
}

variable "enable_karpenter" {
  description = "Create Karpenter controller IRSA role, node role/instance profile, and interruption queue."
  type        = bool
  default     = true
}

variable "karpenter_namespace" {
  description = "Namespace/service-account name Karpenter runs as (used for the IRSA trust)."
  type        = string
  default     = "karpenter"
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
