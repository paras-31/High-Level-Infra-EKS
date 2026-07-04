output "load_balancer_controller_role_arn" {
  description = "IRSA role ARN for the AWS Load Balancer Controller. Annotate its service account with this."
  value       = try(aws_iam_role.lbc[0].arn, null)
}

output "external_dns_role_arn" {
  description = "IRSA role ARN for external-dns."
  value       = try(aws_iam_role.external_dns[0].arn, null)
}

output "karpenter_controller_role_arn" {
  description = "IRSA role ARN for the Karpenter controller."
  value       = try(aws_iam_role.karpenter_controller[0].arn, null)
}

output "karpenter_node_role_name" {
  description = "IAM role name for Karpenter-launched nodes (reference in EC2NodeClass)."
  value       = try(aws_iam_role.karpenter_node[0].name, null)
}

output "karpenter_node_instance_profile_name" {
  description = "Instance profile name for Karpenter-launched nodes."
  value       = try(aws_iam_instance_profile.karpenter_node[0].name, null)
}

output "karpenter_interruption_queue_name" {
  description = "SQS interruption queue name (set in Karpenter Helm values)."
  value       = try(aws_sqs_queue.karpenter_interruption[0].name, null)
}
