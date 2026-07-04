output "cluster_name" {
  value       = module.platform.cluster_name
  description = "EKS cluster name."
}

output "cluster_endpoint" {
  value       = module.platform.cluster_endpoint
  description = "EKS API endpoint."
}

output "configure_kubectl" {
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.platform.cluster_name}"
  description = "Command to update kubeconfig."
}

output "ecr_repository_urls" {
  value       = module.platform.ecr_repository_urls
  description = "ECR repository URLs."
}

output "karpenter_controller_role_arn" {
  value       = module.platform.karpenter_controller_role_arn
  description = "Annotate the Karpenter SA with this."
}
