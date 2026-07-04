###############################################################################
# AWS Config — continuous resource recording + managed compliance rules
###############################################################################

data "aws_iam_policy_document" "config_assume" {
  count = var.enable_config ? 1 : 0
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "config" {
  count              = var.enable_config ? 1 : 0
  name               = "${var.name_prefix}-config"
  assume_role_policy = data.aws_iam_policy_document.config_assume[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "config" {
  count      = var.enable_config ? 1 : 0
  role       = aws_iam_role.config[0].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "this" {
  count    = var.enable_config ? 1 : 0
  name     = "${var.name_prefix}-recorder"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "this" {
  count          = var.enable_config ? 1 : 0
  name           = "${var.name_prefix}-delivery"
  s3_bucket_name = aws_s3_bucket.logs.id
  s3_key_prefix  = "config"

  snapshot_delivery_properties {
    delivery_frequency = "TwentyFour_Hours"
  }

  depends_on = [aws_config_configuration_recorder.this]
}

resource "aws_config_configuration_recorder_status" "this" {
  count      = var.enable_config ? 1 : 0
  name       = aws_config_configuration_recorder.this[0].name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.this]
}

# --- A starter set of managed compliance rules ------------------------------ #
locals {
  config_rules = var.enable_config ? {
    s3-bucket-public-read-prohibited  = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
    s3-bucket-public-write-prohibited = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
    s3-bucket-ssl-requests-only       = "S3_BUCKET_SSL_REQUESTS_ONLY"
    encrypted-volumes                 = "ENCRYPTED_VOLUMES"
    iam-user-mfa-enabled              = "IAM_USER_MFA_ENABLED"
    root-account-mfa-enabled          = "ROOT_ACCOUNT_MFA_ENABLED"
    ec2-imdsv2-check                  = "EC2_IMDSV2_CHECK"
    eks-secrets-encrypted             = "EKS_SECRETS_ENCRYPTED"
    eks-endpoint-no-public-access     = "EKS_ENDPOINT_NO_PUBLIC_ACCESS"
    cloudtrail-enabled                = "CLOUD_TRAIL_ENABLED"
  } : {}
}

resource "aws_config_config_rule" "managed" {
  for_each = local.config_rules

  name = "${var.name_prefix}-${each.key}"
  source {
    owner             = "AWS"
    source_identifier = each.value
  }
  tags       = var.tags
  depends_on = [aws_config_configuration_recorder.this]
}
