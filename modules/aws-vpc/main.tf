################################################################################
# VPC
################################################################################

resource "aws_vpc" "this" {
  assign_generated_ipv6_cidr_block = var.assign_generated_ipv6_cidr_block
  cidr_block                       = var.cidr_block
  enable_dns_hostnames             = var.enable_dns_hostnames
  enable_dns_support               = var.enable_dns_support
  instance_tenancy                 = var.instance_tenancy

  enable_network_address_usage_metrics = var.enable_network_address_usage_metrics

  tags = local.tags
}

################################################################################
# Internet Gateway
################################################################################

resource "aws_internet_gateway" "this" {
  count = var.create_igw ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(
    local.tags,
    {
      Name = "${var.name}-igw"
    }
  )
}

################################################################################
# Default Security Group (locked down - no rules)
################################################################################

resource "aws_default_security_group" "this" {
  count = var.manage_default_security_group ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(
    local.tags,
    {
      Name = "${var.name}-default-sg"
    }
  )
}

################################################################################
# VPC Flow Logs
################################################################################

resource "aws_flow_log" "this" {
  count = local.create_flow_log ? 1 : 0

  iam_role_arn             = local.create_flow_log_iam_role ? aws_iam_role.flow_log[0].arn : var.flow_log_iam_role_arn
  log_destination          = local.create_flow_log_log_group ? aws_cloudwatch_log_group.flow_log[0].arn : var.flow_log_destination_arn
  log_destination_type     = var.flow_log_destination_type
  max_aggregation_interval = var.flow_log_max_aggregation_interval
  traffic_type             = var.flow_log_traffic_type
  vpc_id                   = aws_vpc.this.id

  tags = merge(
    local.tags,
    {
      Name = "${var.name}-flow-log"
    }
  )


  lifecycle {
    precondition {
      condition     = var.flow_log_destination_type != "s3" || var.flow_log_destination_arn != null
      error_message = "flow_log_destination_arn is required when flow_log_destination_type is 's3'."
    }
    precondition {
      condition     = var.flow_log_destination_type != "cloud-watch-logs" || var.flow_log_destination_arn == null || var.flow_log_iam_role_arn != null
      error_message = "flow_log_iam_role_arn is required when providing an external flow_log_destination_arn with cloud-watch-logs destination type."
    }
  }
}

################################################################################
# Flow Log CloudWatch Log Group
################################################################################

resource "aws_cloudwatch_log_group" "flow_log" {
  count = local.create_flow_log_log_group ? 1 : 0

  kms_key_id        = var.flow_log_cloudwatch_kms_key_id
  name              = "/aws/vpc-flow-log/${aws_vpc.this.id}"
  retention_in_days = var.flow_log_cloudwatch_log_group_retention_in_days

  tags = local.tags
}

################################################################################
# Flow Log IAM Role (for CloudWatch Logs destination)
################################################################################

data "aws_caller_identity" "current" {
  count = local.create_flow_log_iam_role ? 1 : 0
}

data "aws_iam_policy_document" "flow_log_assume_role" {
  count = local.create_flow_log_iam_role ? 1 : 0

  statement {
    sid     = "AllowVPCFlowLogsAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current[0].account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:ec2:*:${data.aws_caller_identity.current[0].account_id}:vpc-flow-log/*"]
    }
  }
}

resource "aws_iam_role" "flow_log" {
  count = local.create_flow_log_iam_role ? 1 : 0

  assume_role_policy = data.aws_iam_policy_document.flow_log_assume_role[0].json
  name               = "${var.name}-vpc-flow-log-role"

  tags = local.tags
}

data "aws_iam_policy_document" "flow_log_permissions" {
  count = local.create_flow_log_iam_role ? 1 : 0

  statement {
    sid    = "AllowCloudWatchLogsWrite"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.flow_log[0].arn}:*"]
  }
}

resource "aws_iam_role_policy" "flow_log" {
  count = local.create_flow_log_iam_role ? 1 : 0

  name   = "${var.name}-vpc-flow-log-policy"
  policy = data.aws_iam_policy_document.flow_log_permissions[0].json
  role   = aws_iam_role.flow_log[0].id
}
