###############################################################################
# EKS-only network additions on top of High-level-VPC (external git module).
# VPC itself is NOT defined here — see modules/platform calling High-level-VPC.
###############################################################################

resource "aws_subnet" "intra" {
  count = length(var.intra_subnet_cidrs)

  vpc_id            = var.vpc_id
  cidr_block        = var.intra_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-intra-${var.azs[count.index]}"
    Tier = "intra"
  })
}

resource "aws_route_table" "intra" {
  count  = length(var.intra_subnet_cidrs) > 0 ? 1 : 0
  vpc_id = var.vpc_id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-rt-intra" })
}

resource "aws_route_table_association" "intra" {
  count          = length(aws_subnet.intra)
  subnet_id      = aws_subnet.intra[count.index].id
  route_table_id = aws_route_table.intra[0].id
}

resource "aws_ec2_tag" "public_elb" {
  for_each    = toset(var.public_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

resource "aws_ec2_tag" "public_cluster" {
  for_each    = toset(var.public_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${var.cluster_name}"
  value       = "shared"
}

resource "aws_ec2_tag" "private_internal_elb" {
  for_each    = toset(var.private_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

resource "aws_ec2_tag" "private_cluster" {
  for_each    = toset(var.private_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${var.cluster_name}"
  value       = "shared"
}

resource "aws_ec2_tag" "private_karpenter" {
  for_each    = toset(var.private_subnet_ids)
  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}
