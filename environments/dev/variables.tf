variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "ap-south-1"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "Admin IP(s) allowed to reach the public EKS API endpoint. Use your laptop public IP as /32."
  type        = list(string)

  validation {
    condition = (
      length(var.cluster_endpoint_public_access_cidrs) > 0 &&
      !contains(var.cluster_endpoint_public_access_cidrs, "0.0.0.0/0") &&
      !contains(var.cluster_endpoint_public_access_cidrs, "::/0")
    )
    error_message = "Set cluster_endpoint_public_access_cidrs to your laptop IP only (e.g. [\"203.0.113.45/32\"]). Open internet (0.0.0.0/0) is forbidden."
  }
}

variable "platform_admin_role_arn" {
  description = "IAM role ARN granted cluster-admin via an EKS access entry."
  type        = string
  default     = null
}
