###############################################################################
# CloudTrail — multi-region, log-file validation, KMS-encrypted
###############################################################################

resource "aws_cloudtrail" "this" {
  count = var.enable_cloudtrail ? 1 : 0

  name                          = "${var.name_prefix}-trail"
  s3_bucket_name                = aws_s3_bucket.logs.id
  s3_key_prefix                 = "cloudtrail"
  is_multi_region_trail         = true
  is_organization_trail         = var.organization_trail
  include_global_service_events = true
  enable_log_file_validation    = true
  kms_key_id                    = var.logs_kms_key_arn

  # Capture management events + all S3 / Lambda data events.
  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:${local.partition}:s3"]
    }
  }

  tags       = var.tags
  depends_on = [aws_s3_bucket_policy.logs]
}
