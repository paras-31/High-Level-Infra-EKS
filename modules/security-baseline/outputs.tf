output "log_bucket_name" {
  description = "Name of the CloudTrail/Config log bucket."
  value       = aws_s3_bucket.logs.id
}

output "cloudtrail_arn" {
  description = "CloudTrail ARN."
  value       = try(aws_cloudtrail.this[0].arn, null)
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID."
  value       = try(aws_guardduty_detector.this[0].id, null)
}

output "config_recorder_name" {
  description = "AWS Config recorder name."
  value       = try(aws_config_configuration_recorder.this[0].name, null)
}
