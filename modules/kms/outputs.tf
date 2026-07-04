output "eks_key_arn" {
  description = "CMK ARN for EKS secrets envelope encryption."
  value       = aws_kms_key.this["eks"].arn
}

output "ebs_key_arn" {
  description = "CMK ARN for EBS / node disk encryption."
  value       = aws_kms_key.this["ebs"].arn
}

output "logs_key_arn" {
  description = "CMK ARN for CloudWatch Logs encryption."
  value       = aws_kms_key.this["logs"].arn
}

output "key_arns" {
  description = "Map of purpose -> key ARN."
  value       = { for k, v in aws_kms_key.this : k => v.arn }
}
