###############################################################################
# EKS control plane, control-plane logging, and managed EKS add-ons
###############################################################################

locals {
  cluster_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
}

# --------------------------------------------------------------------------- #
# Control-plane log group (created explicitly for KMS + retention control)
# --------------------------------------------------------------------------- #
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.control_plane_log_retention_days
  kms_key_id        = var.logs_kms_key_arn
  tags              = var.tags
}

# --------------------------------------------------------------------------- #
# Additional security group for the control plane (nodes talk to this)
# --------------------------------------------------------------------------- #
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-additional"
  description = "Additional control-plane security group"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.cluster_name}-cluster-additional" })

  lifecycle {
    create_before_destroy = true
  }
}

# --------------------------------------------------------------------------- #
# EKS cluster
# --------------------------------------------------------------------------- #
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.intra_subnet_ids)
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = local.cluster_public_access_cidrs
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  # Do NOT set bootstrap_self_managed_addons=false on existing clusters (forces replacement).
  # Stale bootstrap vpc-cni is fixed via version-pinned aws_eks_addon + OVERWRITE in addons.tf.

  # Envelope-encrypt Kubernetes secrets with the customer-managed KMS key.
  encryption_config {
    provider {
      key_arn = var.eks_kms_key_arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_cloudwatch_log_group.cluster,
  ]
}

# Add-ons are defined in addons.tf (version-pinned, ordered before node groups).
