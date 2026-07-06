variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "ap-south-1"
}

variable "platform_admin_role_arn" {
  description = "IAM role ARN granted cluster-admin via an EKS access entry."
  type        = string
  default     = null
}
