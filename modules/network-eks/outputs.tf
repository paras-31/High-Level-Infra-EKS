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

output "vpc_endpoint_ids" {
  description = "Created VPC endpoint IDs (used to gate EKS node joins on network readiness)."
  value = concat(
    [for ep in aws_vpc_endpoint.interface : ep.id],
    try([aws_vpc_endpoint.s3[0].id], []),
  )
}

output "network_ready" {
  description = "Changes when VPC endpoints exist and DNS propagation wait completes."
  value       = var.enable_vpc_endpoints ? time_sleep.wait_for_vpce_dns[0].id : "disabled"
}
