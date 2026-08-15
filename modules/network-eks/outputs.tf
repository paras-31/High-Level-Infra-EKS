output "intra_subnet_ids" {
  description = "Intra subnet IDs for EKS control-plane ENIs."
  value       = aws_subnet.intra[*].id
}

output "flow_log_group_name" {
  value = try(aws_cloudwatch_log_group.flow_log[0].name, null)
}

output "vpce_security_group_id" {
  value = try(aws_security_group.vpce[0].id, null)
}
