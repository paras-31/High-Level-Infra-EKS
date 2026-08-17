###############################################################################
# IAM — cluster role, node role, OIDC provider, EBS CSI IRSA role
###############################################################################

data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  iam_policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy"
}

# --------------------------------------------------------------------------- #
# EKS cluster service role
# --------------------------------------------------------------------------- #
data "aws_iam_policy_document" "cluster_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name                 = "${var.cluster_name}-cluster"
  assume_role_policy   = data.aws_iam_policy_document.cluster_assume.json
  permissions_boundary = var.permissions_boundary_arn
  tags                 = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster" {
  for_each = {
    AmazonEKSClusterPolicy         = "AmazonEKSClusterPolicy"
    AmazonEKSVPCResourceController = "AmazonEKSVPCResourceController"
  }
  role       = aws_iam_role.cluster.name
  policy_arn = "${local.iam_policy_arn}/${each.value}"
}

# --------------------------------------------------------------------------- #
# Worker node role (shared by managed node groups)
# --------------------------------------------------------------------------- #
data "aws_iam_policy_document" "node_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name                 = "${var.cluster_name}-node"
  assume_role_policy   = data.aws_iam_policy_document.node_assume.json
  permissions_boundary = var.permissions_boundary_arn
  tags                 = var.tags
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = {
    AmazonEKSWorkerNodePolicy          = "AmazonEKSWorkerNodePolicy"
    AmazonEC2ContainerRegistryReadOnly = "AmazonEC2ContainerRegistryReadOnly"
    AmazonSSMManagedInstanceCore       = "AmazonSSMManagedInstanceCore"
    AmazonEKS_CNI_Policy               = "AmazonEKS_CNI_Policy"
  }
  role       = aws_iam_role.node.name
  policy_arn = "${local.iam_policy_arn}/${each.value}"
}

# --------------------------------------------------------------------------- #
# IAM OIDC provider (foundation for IRSA)
# --------------------------------------------------------------------------- #
data "tls_certificate" "oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]
  tags            = var.tags
}

locals {
  oidc_provider_url = replace(aws_iam_openid_connect_provider.this.url, "https://", "")
}

# VPC CNI uses the node instance role (AmazonEKS_CNI_Policy) — not IRSA — for reliable
# bootstrap on private clusters. IRSA for vpc-cni caused Degraded addons on k8s 1.31.

# --------------------------------------------------------------------------- #
# IRSA role: EBS CSI driver (+ permission to use the EBS CMK)
# --------------------------------------------------------------------------- #
data "aws_iam_policy_document" "ebs_csi_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name                 = "${var.cluster_name}-ebs-csi"
  assume_role_policy   = data.aws_iam_policy_document.ebs_csi_assume.json
  permissions_boundary = var.permissions_boundary_arn
  tags                 = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "${local.iam_policy_arn}/service-role/AmazonEBSCSIDriverPolicy"
}

# Allow the CSI driver to use the customer-managed EBS key.
data "aws_iam_policy_document" "ebs_csi_kms" {
  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
      "kms:GenerateDataKey*", "kms:DescribeKey",
    ]
    resources = [var.ebs_kms_key_arn]
  }
  statement {
    effect    = "Allow"
    actions   = ["kms:CreateGrant"]
    resources = [var.ebs_kms_key_arn]
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}

resource "aws_iam_role_policy" "ebs_csi_kms" {
  name   = "${var.cluster_name}-ebs-csi-kms"
  role   = aws_iam_role.ebs_csi.id
  policy = data.aws_iam_policy_document.ebs_csi_kms.json
}
