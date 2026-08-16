###############################################################################
# KMS module — customer-managed keys for encryption-at-rest
#
# Creates one CMK per purpose (EKS secrets, EBS volumes, CloudWatch logs) so
# key policies and rotation can be reasoned about independently.
###############################################################################

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_root = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"

  keys = {
    eks  = "CMK for EKS envelope-encryption of Kubernetes secrets"
    ebs  = "CMK for EBS volume / EKS node disk encryption"
    logs = "CMK for CloudWatch Logs encryption"
  }
}

resource "aws_kms_key" "this" {
  for_each = local.keys

  description             = each.value
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true
  multi_region            = false

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid       = "EnableRootAccount"
          Effect    = "Allow"
          Principal = { AWS = local.account_root }
          Action    = "kms:*"
          Resource  = "*"
        }
      ],
      each.key == "logs" ? [
        {
          Sid       = "AllowCloudWatchLogs"
          Effect    = "Allow"
          Principal = { Service = "logs.${var.aws_region}.amazonaws.com" }
          Action = [
            "kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*",
            "kms:GenerateDataKey*", "kms:Describe*"
          ]
          Resource = "*"
          Condition = {
            ArnLike = {
              "kms:EncryptionContext:aws:logs:arn" = "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
            }
          }
        },
        {
          Sid       = "AllowCloudTrail"
          Effect    = "Allow"
          Principal = { Service = "cloudtrail.amazonaws.com" }
          Action = [
            "kms:GenerateDataKey*", "kms:Decrypt", "kms:DescribeKey"
          ]
          Resource = "*"
          Condition = {
            StringLike = {
              "kms:EncryptionContext:aws:cloudtrail:arn" = "arn:${data.aws_partition.current.partition}:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*"
            }
          }
        },
        {
          Sid       = "AllowCloudTrailDescribe"
          Effect    = "Allow"
          Principal = { Service = "cloudtrail.amazonaws.com" }
          Action    = ["kms:DescribeKey"]
          Resource  = "*"
        }
      ] : [],
      each.key == "ebs" ? [
        {
          Sid    = "AllowEBSVolumeEncryptionInAccount"
          Effect = "Allow"
          Principal = {
            AWS = "*"
          }
          Action = [
            "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
            "kms:GenerateDataKey*", "kms:CreateGrant", "kms:DescribeKey"
          ]
          Resource = "*"
          Condition = {
            StringEquals = {
              "kms:CallerAccount" = data.aws_caller_identity.current.account_id
              "kms:ViaService"    = "ec2.${var.aws_region}.amazonaws.com"
            }
          }
        }
      ] : []
    )
  })

  tags = merge(var.tags, { Purpose = each.key })
}

resource "aws_kms_alias" "this" {
  for_each      = local.keys
  name          = "alias/${var.name_prefix}-${each.key}"
  target_key_id = aws_kms_key.this[each.key].key_id
}
