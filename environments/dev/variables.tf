variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "ap-south-1"
}

variable "admin_access_cidrs" {
  description = "Your laptop public IP as /32 — only this host can reach the EKS API from the internet."
  type        = list(string)

  validation {
    condition = (
      length(var.admin_access_cidrs) > 0 &&
      !contains(var.admin_access_cidrs, "0.0.0.0/0") &&
      !contains(var.admin_access_cidrs, "::/0")
    )
    error_message = "Set admin_access_cidrs to your public IP as /32, e.g. [\"134.238.10.24/32\"]."
  }
}

variable "platform_admin_role_arn" {
  description = "IAM role ARN granted cluster-admin via an EKS access entry."
  type        = string
  default     = null
}
