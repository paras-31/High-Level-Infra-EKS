###############################################################################
# Karpenter — controller IRSA role, node role + instance profile,
# and the spot-interruption SQS queue + EventBridge rules.
# Controller SA: <karpenter_namespace>/karpenter
###############################################################################

data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  karpenter_arn_prefix = "arn:${data.aws_partition.current.partition}:iam::aws:policy"
  account_id           = data.aws_caller_identity.current.account_id
}

# --------------------------------------------------------------------------- #
# Karpenter node role + instance profile (nodes Karpenter launches)
# --------------------------------------------------------------------------- #
data "aws_iam_policy_document" "karpenter_node_assume" {
  count = var.enable_karpenter ? 1 : 0
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "karpenter_node" {
  count                = var.enable_karpenter ? 1 : 0
  name                 = "${var.cluster_name}-karpenter-node"
  assume_role_policy   = data.aws_iam_policy_document.karpenter_node_assume[0].json
  permissions_boundary = var.permissions_boundary_arn
  tags                 = var.tags
}

resource "aws_iam_role_policy_attachment" "karpenter_node" {
  for_each = var.enable_karpenter ? toset([
    "${local.karpenter_arn_prefix}/AmazonEKSWorkerNodePolicy",
    "${local.karpenter_arn_prefix}/AmazonEKS_CNI_Policy",
    "${local.karpenter_arn_prefix}/AmazonEC2ContainerRegistryReadOnly",
    "${local.karpenter_arn_prefix}/AmazonSSMManagedInstanceCore",
  ]) : toset([])
  role       = aws_iam_role.karpenter_node[0].name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "karpenter_node" {
  count = var.enable_karpenter ? 1 : 0
  name  = "${var.cluster_name}-karpenter-node"
  role  = aws_iam_role.karpenter_node[0].name
  tags  = var.tags
}

# --------------------------------------------------------------------------- #
# Karpenter controller IRSA role
# --------------------------------------------------------------------------- #
data "aws_iam_policy_document" "karpenter_controller_assume" {
  count = var.enable_karpenter ? 1 : 0
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.karpenter_namespace}:karpenter"]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "karpenter_controller" {
  count                = var.enable_karpenter ? 1 : 0
  name                 = "${var.cluster_name}-karpenter-controller"
  assume_role_policy   = data.aws_iam_policy_document.karpenter_controller_assume[0].json
  permissions_boundary = var.permissions_boundary_arn
  tags                 = var.tags
}

resource "aws_iam_role_policy" "karpenter_controller" {
  count = var.enable_karpenter ? 1 : 0
  name  = "${var.cluster_name}-karpenter-controller"
  role  = aws_iam_role.karpenter_controller[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowScopedEC2InstanceAccessActions"
        Effect = "Allow"
        Action = ["ec2:RunInstances", "ec2:CreateFleet"]
        Resource = [
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}::image/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}::snapshot/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:security-group/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:subnet/*"
        ]
      },
      {
        Sid      = "AllowScopedEC2LaunchTemplateAccessActions"
        Effect   = "Allow"
        Action   = ["ec2:RunInstances", "ec2:CreateFleet"]
        Resource = "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:launch-template/*"
        Condition = {
          StringEquals = { "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned" }
          StringLike   = { "aws:ResourceTag/karpenter.sh/nodepool" = "*" }
        }
      },
      {
        Sid      = "AllowScopedEC2InstanceActionsWithTags"
        Effect   = "Allow"
        Action   = ["ec2:RunInstances", "ec2:CreateFleet", "ec2:CreateLaunchTemplate"]
        Resource = ["arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:fleet/*", "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:instance/*", "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:volume/*", "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:network-interface/*", "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:launch-template/*", "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:spot-instances-request/*"]
        Condition = {
          StringEquals = { "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}" = "owned" }
          StringLike   = { "aws:RequestTag/karpenter.sh/nodepool" = "*" }
        }
      },
      {
        Sid      = "AllowScopedResourceCreationTagging"
        Effect   = "Allow"
        Action   = ["ec2:CreateTags"]
        Resource = ["arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:fleet/*", "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:instance/*", "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:volume/*", "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:network-interface/*", "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:launch-template/*", "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:spot-instances-request/*"]
        Condition = {
          StringEquals = { "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}" = "owned", "ec2:CreateAction" = ["RunInstances", "CreateFleet", "CreateLaunchTemplate"] }
        }
      },
      {
        Sid       = "AllowRegionalReadActions"
        Effect    = "Allow"
        Action    = ["ec2:DescribeAvailabilityZones", "ec2:DescribeImages", "ec2:DescribeInstances", "ec2:DescribeInstanceTypeOfferings", "ec2:DescribeInstanceTypes", "ec2:DescribeLaunchTemplates", "ec2:DescribeSecurityGroups", "ec2:DescribeSpotPriceHistory", "ec2:DescribeSubnets"]
        Resource  = "*"
        Condition = { StringEquals = { "aws:RequestedRegion" = var.aws_region } }
      },
      {
        Sid      = "AllowScopedInstanceProfileActions"
        Effect   = "Allow"
        Action   = ["iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile", "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile", "iam:TagInstanceProfile"]
        Resource = "*"
      },
      {
        Sid      = "AllowInstanceProfileReadActions"
        Effect   = "Allow"
        Action   = ["iam:GetInstanceProfile"]
        Resource = "*"
      },
      {
        Sid       = "AllowPassingInstanceRole"
        Effect    = "Allow"
        Action    = ["iam:PassRole"]
        Resource  = aws_iam_role.karpenter_node[0].arn
        Condition = { StringEquals = { "iam:PassedToService" = "ec2.amazonaws.com" } }
      },
      {
        Sid       = "AllowTerminateInstances"
        Effect    = "Allow"
        Action    = ["ec2:TerminateInstances", "ec2:DeleteLaunchTemplate"]
        Resource  = "*"
        Condition = { StringEquals = { "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned" } }
      },
      {
        Sid      = "AllowInterruptionQueueActions"
        Effect   = "Allow"
        Action   = ["sqs:DeleteMessage", "sqs:GetQueueUrl", "sqs:ReceiveMessage"]
        Resource = aws_sqs_queue.karpenter_interruption[0].arn
      },
      {
        Sid      = "AllowEKSClusterEndpointLookup"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = "arn:${data.aws_partition.current.partition}:eks:${var.aws_region}:${local.account_id}:cluster/${var.cluster_name}"
      },
      {
        Sid      = "AllowSSMReadActions"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}::parameter/aws/service/*"
      },
      {
        Sid      = "AllowPricingReadActions"
        Effect   = "Allow"
        Action   = ["pricing:GetProducts"]
        Resource = "*"
      }
    ]
  })
}

# --------------------------------------------------------------------------- #
# Interruption queue (spot rebalance / termination / health events)
# --------------------------------------------------------------------------- #
resource "aws_sqs_queue" "karpenter_interruption" {
  count                     = var.enable_karpenter ? 1 : 0
  name                      = "${var.cluster_name}-karpenter"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
  tags                      = var.tags
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  count     = var.enable_karpenter ? 1 : 0
  queue_url = aws_sqs_queue.karpenter_interruption[0].url
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = ["events.amazonaws.com", "sqs.amazonaws.com"] }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.karpenter_interruption[0].arn
    }]
  })
}

locals {
  karpenter_events = var.enable_karpenter ? {
    spot_interruption = { source = ["aws.ec2"], detail_type = ["EC2 Spot Instance Interruption Warning"] }
    rebalance         = { source = ["aws.ec2"], detail_type = ["EC2 Instance Rebalance Recommendation"] }
    state_change      = { source = ["aws.ec2"], detail_type = ["EC2 Instance State-change Notification"] }
    health_event      = { source = ["aws.health"], detail_type = ["AWS Health Event"] }
  } : {}
}

resource "aws_cloudwatch_event_rule" "karpenter" {
  for_each      = local.karpenter_events
  name          = "${var.cluster_name}-karpenter-${each.key}"
  event_pattern = jsonencode({ source = each.value.source, "detail-type" = each.value.detail_type })
  tags          = var.tags
}

resource "aws_cloudwatch_event_target" "karpenter" {
  for_each  = local.karpenter_events
  rule      = aws_cloudwatch_event_rule.karpenter[each.key].name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.karpenter_interruption[0].arn
}
