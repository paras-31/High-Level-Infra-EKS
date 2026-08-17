data "aws_region" "current" {}

resource "aws_security_group" "vpce" {
  count       = var.enable_vpc_endpoints && length(var.interface_endpoints) > 0 ? 1 : 0
  name        = "${var.name_prefix}-vpce"
  description = "Allow HTTPS from within the VPC to interface endpoints"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    description = "Return traffic to VPC clients"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-vpce" })
}

resource "aws_vpc_endpoint" "s3" {
  count = var.enable_vpc_endpoints && var.enable_s3_gateway_endpoint ? 1 : 0

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids
  tags              = merge(var.tags, { Name = "${var.name_prefix}-s3-vpce" })
}

resource "aws_vpc_endpoint" "interface" {
  for_each = var.enable_vpc_endpoints && var.enable_interface_endpoints ? toset(var.interface_endpoints) : toset([])

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpce[0].id]

  tags = merge(var.tags, { Name = "${var.name_prefix}-${each.value}-vpce" })
}

# Nodes pull ECR images immediately on boot — wait for interface endpoint DNS.
resource "time_sleep" "wait_for_vpce_dns" {
  count = var.enable_vpc_endpoints ? 1 : 0

  create_duration = "120s"

  depends_on = [
    aws_vpc_endpoint.s3,
    aws_vpc_endpoint.interface,
  ]
}
