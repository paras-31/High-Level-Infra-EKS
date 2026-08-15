variable "name_prefix" { type = string }
variable "vpc_id" { type = string }
variable "vpc_cidr_block" { type = string }
variable "cluster_name" { type = string }
variable "azs" { type = list(string) }

variable "public_subnet_ids" { type = list(string) }
variable "private_subnet_ids" { type = list(string) }
variable "private_route_table_ids" { type = list(string) }

variable "intra_subnet_cidrs" {
  type    = list(string)
  default = []
}

variable "enable_flow_logs" {
  type    = bool
  default = true
}

variable "flow_log_retention_days" {
  type    = number
  default = 90
}

variable "logs_kms_key_arn" {
  type    = string
  default = null
}

variable "enable_vpc_endpoints" {
  type    = bool
  default = true
}

variable "enable_s3_gateway_endpoint" {
  type    = bool
  default = true
}

variable "enable_interface_endpoints" {
  type    = bool
  default = true
}

variable "interface_endpoints" {
  type = list(string)
  default = [
    "ecr.api", "ecr.dkr", "ec2", "sts", "logs", "elasticloadbalancing", "autoscaling", "eks",
  ]
}

variable "tags" {
  type    = map(string)
  default = {}
}
