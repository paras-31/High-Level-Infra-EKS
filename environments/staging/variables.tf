variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "ap-south-1"
}

variable "admin_access_cidrs" {
  description = "Admin IP(s) as /32 for EKS public API access."
  type        = list(string)
  default     = ["134.238.10.24/32"]
}

variable "platform_admin_role_arn" {
  description = "IAM role ARN granted cluster-admin via an EKS access entry."
  type        = string
  default     = null
}
