variable "name_prefix" {
  description = "Prefix for security baseline resource names."
  type        = string
}

variable "log_bucket_name" {
  description = "Globally-unique S3 bucket name for CloudTrail + Config logs."
  type        = string
}

variable "logs_kms_key_arn" {
  description = "KMS key ARN for encrypting logs (bucket, CloudTrail). Null uses SSE-S3."
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "Days to retain logs in the bucket before expiry."
  type        = number
  default     = 365
}

variable "enable_cloudtrail" {
  description = "Enable the multi-region CloudTrail."
  type        = bool
  default     = true
}

variable "organization_trail" {
  description = "Make CloudTrail an organization trail (requires org management account)."
  type        = bool
  default     = false
}

variable "enable_guardduty" {
  description = "Enable GuardDuty with EKS audit + runtime monitoring."
  type        = bool
  default     = true
}

variable "enable_security_hub" {
  description = "Enable Security Hub with AWS Foundational + CIS standards."
  type        = bool
  default     = true
}

variable "security_hub_already_enabled" {
  description = "Set true when the account is already subscribed to Security Hub (e.g. org-level enablement)."
  type        = bool
  default     = false
}

variable "enable_config" {
  description = "Enable AWS Config recorder + managed compliance rules."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
