###############################################################################
# KMS module — customer-managed keys for encryption-at-rest
#
# Creates one CMK per purpose (EKS secrets, EBS volumes, CloudWatch logs) so
# key policies and rotation can be reasoned about independently.
#
# Policies use aws_iam_policy_document to avoid Terraform tuple/list typing
# issues when merging heterogeneous JSON statements.
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

  key_policies = {
    eks  = data.aws_iam_policy_document.eks.json
    ebs  = data.aws_iam_policy_document.ebs.json
    logs = data.aws_iam_policy_document.logs.json
  }
}

# ── Root account access (shared by all keys) ─────────────────────────────────
data "aws_iam_policy_document" "root" {
  statement {
    sid    = "EnableRootAccount"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [local.account_root]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }
}

# ── EKS secrets key — root only ──────────────────────────────────────────────
data "aws_iam_policy_document" "eks" {
  source_policy_documents = [data.aws_iam_policy_document.root.json]
}

# ── EBS key — root + EC2 ViaService in this account ──────────────────────────
data "aws_iam_policy_document" "ebs" {
  source_policy_documents = [data.aws_iam_policy_document.root.json]

  statement {
    sid    = "AllowEBSVolumeEncryptionInAccount"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:DescribeKey",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ec2.${var.aws_region}.amazonaws.com"]
    }
  }
}

# ── Logs key — root + CloudWatch Logs + CloudTrail ───────────────────────────
data "aws_iam_policy_document" "logs" {
  source_policy_documents = [data.aws_iam_policy_document.root.json]

  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logs.${var.aws_region}.amazonaws.com"]
    }

    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    resources = ["*"]

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values = [
        "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*",
      ]
    }
  }

  statement {
    sid    = "AllowCloudTrail"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = [
      "kms:GenerateDataKey*",
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values = [
        "arn:${data.aws_partition.current.partition}:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*",
      ]
    }
  }

  statement {
    sid    = "AllowCloudTrailDescribe"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["kms:DescribeKey"]
    resources = ["*"]
  }
}

resource "aws_kms_key" "this" {
  for_each = local.keys

  description             = each.value
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true
  multi_region            = false
  policy                  = local.key_policies[each.key]

  tags = merge(var.tags, { Purpose = each.key })
}

resource "aws_kms_alias" "this" {
  for_each      = local.keys
  name          = "alias/${var.name_prefix}-${each.key}"
  target_key_id = aws_kms_key.this[each.key].key_id
}
