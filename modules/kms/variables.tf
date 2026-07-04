variable "name_prefix" {
  description = "Prefix for KMS alias names, e.g. eks-prod."
  type        = string
}

variable "aws_region" {
  description = "AWS region (needed for the CloudWatch Logs key policy)."
  type        = string
}

variable "deletion_window_in_days" {
  description = "Waiting period before a scheduled key deletion completes."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
