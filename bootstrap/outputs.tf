output "state_bucket_name" {
  description = "Name of the S3 bucket holding Terraform state."
  value       = aws_s3_bucket.state.id
}

output "lock_table_name" {
  description = "Name of the DynamoDB lock table."
  value       = aws_dynamodb_table.lock.name
}

output "kms_key_arn" {
  description = "ARN of the KMS key encrypting the state bucket."
  value       = aws_kms_key.state.arn
}

output "backend_config_hint" {
  description = "Copy these values into each environment's backend.tf."
  value = {
    bucket         = aws_s3_bucket.state.id
    dynamodb_table = aws_dynamodb_table.lock.name
    kms_key_id     = aws_kms_key.state.arn
    region         = var.aws_region
    encrypt        = true
  }
}
