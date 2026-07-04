# --- Network ---------------------------------------------------------------- #
output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID."
}

output "private_subnets" {
  value       = module.vpc.private_subnets
  description = "Private subnet IDs."
}

output "public_subnets" {
  value       = module.vpc.public_subnets
  description = "Public subnet IDs."
}

# --- Cluster ---------------------------------------------------------------- #
output "cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS cluster name."
}

output "cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "EKS API endpoint."
}

output "cluster_certificate_authority_data" {
  value       = module.eks.cluster_certificate_authority_data
  description = "Cluster CA data."
  sensitive   = true
}

output "cluster_version" {
  value       = module.eks.cluster_version
  description = "Kubernetes version."
}

output "oidc_provider_arn" {
  value       = module.eks.oidc_provider_arn
  description = "IAM OIDC provider ARN (for IRSA)."
}

output "oidc_provider_url" {
  value       = module.eks.oidc_provider_url
  description = "OIDC provider URL."
}

output "node_security_group_id" {
  value       = module.eks.node_security_group_id
  description = "Worker node security group ID."
}

# --- KMS -------------------------------------------------------------------- #
output "kms_key_arns" {
  value       = module.kms.key_arns
  description = "Map of KMS key ARNs (eks/ebs/logs)."
}

# --- Add-on IRSA ------------------------------------------------------------ #
output "load_balancer_controller_role_arn" {
  value       = module.eks_addons.load_balancer_controller_role_arn
  description = "IRSA role ARN for the AWS Load Balancer Controller."
}

output "external_dns_role_arn" {
  value       = module.eks_addons.external_dns_role_arn
  description = "IRSA role ARN for external-dns."
}

output "karpenter_controller_role_arn" {
  value       = module.eks_addons.karpenter_controller_role_arn
  description = "IRSA role ARN for the Karpenter controller."
}

output "karpenter_node_instance_profile_name" {
  value       = module.eks_addons.karpenter_node_instance_profile_name
  description = "Instance profile for Karpenter-launched nodes."
}

output "karpenter_interruption_queue_name" {
  value       = module.eks_addons.karpenter_interruption_queue_name
  description = "Karpenter interruption SQS queue name."
}

# --- ECR -------------------------------------------------------------------- #
output "ecr_repository_urls" {
  value       = module.ecr.repository_urls
  description = "Map of ECR repository name -> URL."
}
