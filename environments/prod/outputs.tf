output "cluster_name" {
  value       = module.platform.cluster_name
  description = "EKS cluster name."
}

output "cluster_endpoint" {
  value       = module.platform.cluster_endpoint
  description = "EKS API endpoint."
}

output "configure_kubectl" {
  description = "Command to update your kubeconfig for this cluster."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.platform.cluster_name}"
}

output "ecr_repository_urls" {
  value       = module.platform.ecr_repository_urls
  description = "ECR repository URLs."
}

output "load_balancer_controller_role_arn" {
  value       = module.platform.load_balancer_controller_role_arn
  description = "Annotate the aws-load-balancer-controller SA with this."
}

output "karpenter_controller_role_arn" {
  value       = module.platform.karpenter_controller_role_arn
  description = "Annotate the Karpenter SA with this."
}

output "karpenter_node_instance_profile_name" {
  value       = module.platform.karpenter_node_instance_profile_name
  description = "Instance profile for Karpenter EC2NodeClass."
}
