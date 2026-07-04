output "role_arn" {
  description = "ARN of the created IAM role (annotate the service account with this)."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the created IAM role."
  value       = aws_iam_role.this.name
}
