output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 CA data for the cluster."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_version" {
  description = "Kubernetes version."
  value       = aws_eks_cluster.this.version
}

output "cluster_security_group_id" {
  description = "EKS-managed cluster (primary) security group ID."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "cluster_additional_security_group_id" {
  description = "Additional control-plane security group ID created by this module."
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "Worker node security group ID."
  value       = aws_security_group.node.id
}

output "node_iam_role_arn" {
  description = "Worker node IAM role ARN."
  value       = aws_iam_role.node.arn
}

output "node_iam_role_name" {
  description = "Worker node IAM role name."
  value       = aws_iam_role.node.name
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN (for IRSA)."
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL without scheme (for IRSA trust conditions)."
  value       = local.oidc_provider_url
}
