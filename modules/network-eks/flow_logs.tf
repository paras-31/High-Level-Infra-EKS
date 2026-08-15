data "aws_iam_policy_document" "flow_log_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "flow_log_permissions" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.flow_log[0].arn}:*"]
  }
}

resource "aws_iam_role" "flow_log" {
  count              = var.enable_flow_logs ? 1 : 0
  name               = "${var.name_prefix}-vpc-flow-log"
  assume_role_policy = data.aws_iam_policy_document.flow_log_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "flow_log" {
  count  = var.enable_flow_logs ? 1 : 0
  name   = "${var.name_prefix}-vpc-flow-log"
  role   = aws_iam_role.flow_log[0].id
  policy = data.aws_iam_policy_document.flow_log_permissions.json
}

resource "aws_cloudwatch_log_group" "flow_log" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/aws/vpc/${var.name_prefix}/flow-logs"
  retention_in_days = var.flow_log_retention_days
  kms_key_id        = var.logs_kms_key_arn
  tags              = var.tags
}

resource "aws_flow_log" "this" {
  count                    = var.enable_flow_logs ? 1 : 0
  vpc_id                   = var.vpc_id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow_log[0].arn
  iam_role_arn             = aws_iam_role.flow_log[0].arn
  max_aggregation_interval = 60
  tags                     = merge(var.tags, { Name = "${var.name_prefix}-flow-log" })
}
