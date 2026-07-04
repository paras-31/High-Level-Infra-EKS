###############################################################################
# Worker nodes — node security group, launch template, managed node groups
###############################################################################

# --------------------------------------------------------------------------- #
# Node security group
# --------------------------------------------------------------------------- #
resource "aws_security_group" "node" {
  name        = "${var.cluster_name}-node"
  description = "EKS worker node security group"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-node"
    # Required so Karpenter/LB-controller can discover this SG.
    "karpenter.sh/discovery"                    = var.cluster_name
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "node_self" {
  description       = "Node to node all traffic"
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = aws_security_group.node.id
}

resource "aws_security_group_rule" "node_from_cluster" {
  description              = "Control plane to nodes (kubelet, extension API servers)"
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  security_group_id        = aws_security_group.node.id
}

resource "aws_security_group_rule" "node_from_cluster_443" {
  description              = "Control plane to nodes on 443 (webhooks)"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  security_group_id        = aws_security_group.node.id
}

resource "aws_security_group_rule" "node_egress" {
  description       = "All egress"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.node.id
}

# Let nodes reach the additional control-plane SG on 443.
resource "aws_security_group_rule" "cluster_from_node_443" {
  description              = "Nodes to control plane on 443"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node.id
  security_group_id        = aws_security_group.cluster.id
}

# --------------------------------------------------------------------------- #
# Launch template — one per node group (IMDSv2, encrypted disk, tagging)
# --------------------------------------------------------------------------- #
resource "aws_launch_template" "node" {
  for_each = var.managed_node_groups

  name_prefix = "${var.cluster_name}-${each.key}-"
  description = "Launch template for EKS node group ${each.key}"

  vpc_security_group_ids = [
    aws_security_group.node.id,
    aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
  ]

  # Enforce IMDSv2 — blocks the classic SSRF -> node-credential-theft path.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  # Encrypted gp3 root volume with the customer-managed key.
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = try(each.value.disk_size, var.node_disk_size)
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.ebs_kms_key_arn
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.cluster_name}-${each.key}"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = var.tags
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# --------------------------------------------------------------------------- #
# Managed node groups
# --------------------------------------------------------------------------- #
resource "aws_eks_node_group" "this" {
  for_each = var.managed_node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-${each.key}"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = try(each.value.instance_types, var.default_instance_types)
  capacity_type  = try(each.value.capacity_type, "ON_DEMAND")

  scaling_config {
    desired_size = each.value.desired_size
    min_size     = each.value.min_size
    max_size     = each.value.max_size
  }

  update_config {
    max_unavailable_percentage = try(each.value.max_unavailable_percentage, 33)
  }

  launch_template {
    id      = aws_launch_template.node[each.key].id
    version = aws_launch_template.node[each.key].latest_version
  }

  labels = try(each.value.labels, {})

  dynamic "taint" {
    for_each = try(each.value.taints, [])
    content {
      key    = taint.value.key
      value  = try(taint.value.value, null)
      effect = taint.value.effect
    }
  }

  tags = merge(var.tags, try(each.value.tags, {}))

  # Roll nodes without downtime; ignore desired_size drift (Karpenter/HPA-adjacent).
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node,
  ]
}
