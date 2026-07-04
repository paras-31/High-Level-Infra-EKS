variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "security_log_bucket_name" {
  description = "Globally-unique S3 bucket name for CloudTrail/Config logs (governance)."
  type        = string
}

variable "platform_admin_role_arn" {
  description = "IAM role ARN granted cluster-admin via an EKS access entry."
  type        = string
  default     = null
}
