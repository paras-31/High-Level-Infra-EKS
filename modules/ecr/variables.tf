variable "repository_names" {
  description = "List of ECR repository names to create."
  type        = list(string)
  default     = []
}

variable "image_tag_mutability" {
  description = "IMMUTABLE (recommended) or MUTABLE."
  type        = string
  default     = "IMMUTABLE"
}

variable "kms_key_arn" {
  description = "KMS key ARN for repository encryption. Null uses AES256."
  type        = string
  default     = null
}

variable "untagged_expiry_days" {
  description = "Days after which untagged images expire."
  type        = number
  default     = 14
}

variable "max_image_count" {
  description = "Maximum number of tagged images to retain per repository."
  type        = number
  default     = 30
}

variable "force_delete" {
  description = "Allow Terraform to delete repositories that still contain images."
  type        = bool
  default     = false
}

variable "repository_policy_json" {
  description = "Optional ECR repository policy (JSON) for cross-account access."
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
