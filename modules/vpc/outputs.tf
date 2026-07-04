output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block."
  value       = aws_vpc.this.cidr_block
}

output "private_subnets" {
  description = "Private subnet IDs (used for EKS nodes)."
  value       = aws_subnet.private[*].id
}

output "public_subnets" {
  description = "Public subnet IDs (used for internet-facing LBs)."
  value       = aws_subnet.public[*].id
}

output "intra_subnets" {
  description = "Intra subnet IDs."
  value       = aws_subnet.intra[*].id
}

output "private_route_table_ids" {
  description = "Private route table IDs."
  value       = aws_route_table.private[*].id
}

output "nat_public_ips" {
  description = "Elastic IPs of the NAT gateways (allowlist these downstream)."
  value       = aws_eip.nat[*].public_ip
}
