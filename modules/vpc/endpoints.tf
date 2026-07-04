###############################################################################
# VPC Endpoints — keep node <-> AWS API traffic on the AWS backbone
#   * S3 as a Gateway endpoint (free, attached to private route tables)
#   * Interface endpoints for ECR/EC2/STS/Logs/ELB/Autoscaling
###############################################################################

data "aws_region" "current" {}

# --- Security group for interface endpoints --------------------------------- #
resource "aws_security_group" "vpce" {
  count       = length(var.interface_endpoints) > 0 ? 1 : 0
  name        = "${local.name}-vpce"
  description = "Allow HTTPS from within the VPC to interface endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${local.name}-vpce" })
}

# --- S3 Gateway endpoint ---------------------------------------------------- #
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id
  tags              = merge(var.tags, { Name = "${local.name}-s3-vpce" })
}

# --- Interface endpoints ---------------------------------------------------- #
resource "aws_vpc_endpoint" "interface" {
  for_each = toset(var.interface_endpoints)

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpce[0].id]

  tags = merge(var.tags, { Name = "${local.name}-${each.value}-vpce" })
}
