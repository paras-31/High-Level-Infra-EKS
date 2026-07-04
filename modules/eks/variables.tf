variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes minor version, e.g. 1.31."
  type        = string
  default     = "1.31"
}

variable "vpc_id" {
  description = "VPC ID the cluster lives in."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for worker nodes and the control-plane ENIs."
  type        = list(string)
}

variable "intra_subnet_ids" {
  description = "Optional additional (intra) subnet IDs for control-plane ENIs."
  type        = list(string)
  default     = []
}

variable "cluster_endpoint_public_access" {
  description = "Whether the public API endpoint is enabled. Keep false for fully private clusters."
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint (only used if public access is on)."
  type        = list(string)
  default     = []
}

variable "eks_kms_key_arn" {
  description = "KMS CMK ARN for secrets envelope encryption."
  type        = string
}

variable "ebs_kms_key_arn" {
  description = "KMS CMK ARN for node EBS encryption."
  type        = string
}

variable "logs_kms_key_arn" {
  description = "KMS CMK ARN for the control-plane CloudWatch log group."
  type        = string
}

variable "control_plane_log_retention_days" {
  description = "Retention for control-plane logs."
  type        = number
  default     = 90
}

variable "default_instance_types" {
  description = "Default instance types for managed node groups."
  type        = list(string)
  default     = ["m6i.large"]
}

variable "node_disk_size" {
  description = "Default root EBS volume size (GiB) for nodes."
  type        = number
  default     = 50
}

variable "permissions_boundary_arn" {
  description = "Optional permissions boundary applied to all IAM roles this module creates."
  type        = string
  default     = null
}

variable "managed_node_groups" {
  description = <<-EOT
    Map of managed node group definitions. Each value supports:
      desired_size, min_size, max_size            (numbers, required)
      instance_types                              (list(string), optional)
      capacity_type                               ("ON_DEMAND" | "SPOT", optional)
      disk_size                                   (number, optional)
      max_unavailable_percentage                  (number, optional)
      labels                                      (map(string), optional)
      taints                                      (list of {key,value,effect}, optional)
      tags                                        (map(string), optional)
  EOT
  type        = any
  default     = {}
}

variable "access_entries" {
  description = <<-EOT
    Map of EKS access entries. Each value:
      principal_arn        (string, required)
      kubernetes_groups    (list(string), optional)
      type                 (string, optional; default STANDARD)
      policy_associations  (list of { policy_arn, access_scope = { type, namespaces } })
  EOT
  type        = any
  default     = {}
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
