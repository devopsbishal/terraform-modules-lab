################################################################################
# Custom Values Unit Tests — AWS VPC Module
#
# Validates that the module correctly applies non-default variable values
# and that conditional resources are created or skipped based on flags.
################################################################################

mock_provider "aws" {
  override_data {
    target = data.aws_caller_identity.current[0]
    values = {
      account_id = "123456789012"
    }
  }

  override_data {
    target = data.aws_iam_policy_document.flow_log_assume_role[0]
    values = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"vpc-flow-logs.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    }
  }

  override_data {
    target = data.aws_iam_policy_document.flow_log_permissions[0]
    values = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"logs:CreateLogStream\",\"logs:PutLogEvents\"],\"Resource\":\"*\"}]}"
    }
  }
}

################################################################################
# Custom VPC Settings
################################################################################

run "test_custom_cidr_block" {
  command = plan

  variables {
    name       = "custom-vpc"
    cidr_block = "172.16.0.0/20"
  }

  assert {
    condition     = aws_vpc.this.cidr_block == "172.16.0.0/20"
    error_message = "Expected VPC cidr_block to be '172.16.0.0/20', got '${aws_vpc.this.cidr_block}'."
  }
}

run "test_custom_dns_support_disabled" {
  command = plan

  variables {
    name               = "custom-vpc"
    cidr_block         = "10.0.0.0/16"
    enable_dns_support = false
  }

  assert {
    condition     = aws_vpc.this.enable_dns_support == false
    error_message = "Expected enable_dns_support to be false when explicitly set."
  }
}

run "test_custom_dns_hostnames_disabled" {
  command = plan

  variables {
    name                 = "custom-vpc"
    cidr_block           = "10.0.0.0/16"
    enable_dns_hostnames = false
  }

  assert {
    condition     = aws_vpc.this.enable_dns_hostnames == false
    error_message = "Expected enable_dns_hostnames to be false when explicitly set."
  }
}

run "test_custom_dedicated_tenancy" {
  command = plan

  variables {
    name             = "custom-vpc"
    cidr_block       = "10.0.0.0/16"
    instance_tenancy = "dedicated"
  }

  assert {
    condition     = aws_vpc.this.instance_tenancy == "dedicated"
    error_message = "Expected instance_tenancy to be 'dedicated', got '${aws_vpc.this.instance_tenancy}'."
  }
}

run "test_custom_ipv6_enabled" {
  command = plan

  variables {
    name                             = "custom-vpc"
    cidr_block                       = "10.0.0.0/16"
    assign_generated_ipv6_cidr_block = true
  }

  assert {
    condition     = aws_vpc.this.assign_generated_ipv6_cidr_block == true
    error_message = "Expected assign_generated_ipv6_cidr_block to be true when explicitly set."
  }
}

run "test_custom_nau_metrics_enabled" {
  command = plan

  variables {
    name                                 = "custom-vpc"
    cidr_block                           = "10.0.0.0/16"
    enable_network_address_usage_metrics = true
  }

  assert {
    condition     = aws_vpc.this.enable_network_address_usage_metrics == true
    error_message = "Expected enable_network_address_usage_metrics to be true when explicitly set."
  }
}

run "test_custom_tags_merged" {
  command = plan

  variables {
    name       = "custom-vpc"
    cidr_block = "10.0.0.0/16"
    tags = {
      Environment = "staging"
      Team        = "platform"
    }
  }

  assert {
    condition     = aws_vpc.this.tags["Name"] == "custom-vpc"
    error_message = "Expected Name tag to be preserved when custom tags are provided."
  }

  assert {
    condition     = aws_vpc.this.tags["Environment"] == "staging"
    error_message = "Expected custom Environment tag to be applied."
  }

  assert {
    condition     = aws_vpc.this.tags["Team"] == "platform"
    error_message = "Expected custom Team tag to be applied."
  }
}

################################################################################
# Internet Gateway Toggle
################################################################################

run "test_custom_igw_disabled" {
  command = plan

  variables {
    name       = "private-vpc"
    cidr_block = "10.0.0.0/16"
    create_igw = false
  }

  assert {
    condition     = length(aws_internet_gateway.this) == 0
    error_message = "Expected no IGW when create_igw is false."
  }
}

run "test_custom_igw_disabled_output_null" {
  command = plan

  variables {
    name       = "private-vpc"
    cidr_block = "10.0.0.0/16"
    create_igw = false
  }

  assert {
    condition     = output.internet_gateway_id == null
    error_message = "Expected internet_gateway_id output to be null when create_igw is false."
  }
}

################################################################################
# Default Security Group Toggle
################################################################################

run "test_custom_default_sg_unmanaged" {
  command = plan

  variables {
    name                          = "custom-vpc"
    cidr_block                    = "10.0.0.0/16"
    manage_default_security_group = false
  }

  assert {
    condition     = length(aws_default_security_group.this) == 0
    error_message = "Expected default security group to not be managed when manage_default_security_group is false."
  }
}

################################################################################
# Flow Logs Disabled
################################################################################

run "test_custom_flow_logs_disabled" {
  command = plan

  variables {
    name             = "custom-vpc"
    cidr_block       = "10.0.0.0/16"
    flow_log_enabled = false
  }

  assert {
    condition     = length(aws_flow_log.this) == 0
    error_message = "Expected no flow log when flow_log_enabled is false."
  }
}

run "test_custom_flow_logs_disabled_no_log_group" {
  command = plan

  variables {
    name             = "custom-vpc"
    cidr_block       = "10.0.0.0/16"
    flow_log_enabled = false
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.flow_log) == 0
    error_message = "Expected no CloudWatch Log Group when flow logs are disabled."
  }
}

run "test_custom_flow_logs_disabled_no_iam_role" {
  command = plan

  variables {
    name             = "custom-vpc"
    cidr_block       = "10.0.0.0/16"
    flow_log_enabled = false
  }

  assert {
    condition     = length(aws_iam_role.flow_log) == 0
    error_message = "Expected no IAM role when flow logs are disabled."
  }
}

run "test_custom_flow_logs_disabled_no_iam_role_policy" {
  command = plan

  variables {
    name             = "custom-vpc"
    cidr_block       = "10.0.0.0/16"
    flow_log_enabled = false
  }

  assert {
    condition     = length(aws_iam_role_policy.flow_log) == 0
    error_message = "Expected no IAM role policy when flow logs are disabled."
  }
}

run "test_custom_flow_logs_disabled_output_null" {
  command = plan

  variables {
    name             = "custom-vpc"
    cidr_block       = "10.0.0.0/16"
    flow_log_enabled = false
  }

  assert {
    condition     = output.flow_log_id == null
    error_message = "Expected flow_log_id output to be null when flow logs are disabled."
  }

  assert {
    condition     = output.flow_log_cloudwatch_log_group_arn == null
    error_message = "Expected flow_log_cloudwatch_log_group_arn output to be null when flow logs are disabled."
  }

  assert {
    condition     = output.flow_log_iam_role_arn == null
    error_message = "Expected flow_log_iam_role_arn output to be null when flow logs are disabled."
  }
}

################################################################################
# Flow Log Custom Settings (CloudWatch destination)
################################################################################

run "test_custom_flow_log_traffic_type_accept" {
  command = plan

  variables {
    name                  = "custom-vpc"
    cidr_block            = "10.0.0.0/16"
    flow_log_traffic_type = "ACCEPT"
  }

  assert {
    condition     = aws_flow_log.this[0].traffic_type == "ACCEPT"
    error_message = "Expected flow log traffic type to be 'ACCEPT', got '${aws_flow_log.this[0].traffic_type}'."
  }
}

run "test_custom_flow_log_traffic_type_reject" {
  command = plan

  variables {
    name                  = "custom-vpc"
    cidr_block            = "10.0.0.0/16"
    flow_log_traffic_type = "REJECT"
  }

  assert {
    condition     = aws_flow_log.this[0].traffic_type == "REJECT"
    error_message = "Expected flow log traffic type to be 'REJECT', got '${aws_flow_log.this[0].traffic_type}'."
  }
}

run "test_custom_flow_log_aggregation_60s" {
  command = plan

  variables {
    name                              = "custom-vpc"
    cidr_block                        = "10.0.0.0/16"
    flow_log_max_aggregation_interval = 60
  }

  assert {
    condition     = aws_flow_log.this[0].max_aggregation_interval == 60
    error_message = "Expected flow log max_aggregation_interval to be 60, got ${aws_flow_log.this[0].max_aggregation_interval}."
  }
}

run "test_custom_cloudwatch_retention_365" {
  command = plan

  variables {
    name                                            = "custom-vpc"
    cidr_block                                      = "10.0.0.0/16"
    flow_log_cloudwatch_log_group_retention_in_days = 365
  }

  assert {
    condition     = aws_cloudwatch_log_group.flow_log[0].retention_in_days == 365
    error_message = "Expected CloudWatch Log Group retention to be 365 days, got ${aws_cloudwatch_log_group.flow_log[0].retention_in_days}."
  }
}

run "test_custom_cloudwatch_kms_key" {
  command = plan

  variables {
    name                           = "custom-vpc"
    cidr_block                     = "10.0.0.0/16"
    flow_log_cloudwatch_kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  }

  assert {
    condition     = aws_cloudwatch_log_group.flow_log[0].kms_key_id == "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
    error_message = "Expected CloudWatch Log Group to use the provided KMS key ARN."
  }
}

################################################################################
# Flow Log with S3 Destination
################################################################################

run "test_custom_flow_log_s3_destination" {
  command = plan

  variables {
    name                      = "custom-vpc"
    cidr_block                = "10.0.0.0/16"
    flow_log_destination_type = "s3"
    flow_log_destination_arn  = "arn:aws:s3:::my-flow-log-bucket"
  }

  assert {
    condition     = aws_flow_log.this[0].log_destination_type == "s3"
    error_message = "Expected flow log destination type to be 's3', got '${aws_flow_log.this[0].log_destination_type}'."
  }

  assert {
    condition     = aws_flow_log.this[0].log_destination == "arn:aws:s3:::my-flow-log-bucket"
    error_message = "Expected flow log destination to be the provided S3 bucket ARN."
  }
}

run "test_custom_flow_log_s3_no_log_group" {
  command = plan

  variables {
    name                      = "custom-vpc"
    cidr_block                = "10.0.0.0/16"
    flow_log_destination_type = "s3"
    flow_log_destination_arn  = "arn:aws:s3:::my-flow-log-bucket"
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.flow_log) == 0
    error_message = "Expected no CloudWatch Log Group when destination is S3."
  }
}

run "test_custom_flow_log_s3_no_iam_role" {
  command = plan

  variables {
    name                      = "custom-vpc"
    cidr_block                = "10.0.0.0/16"
    flow_log_destination_type = "s3"
    flow_log_destination_arn  = "arn:aws:s3:::my-flow-log-bucket"
  }

  assert {
    condition     = length(aws_iam_role.flow_log) == 0
    error_message = "Expected no IAM role when flow log destination is S3."
  }
}

run "test_custom_flow_log_s3_no_iam_role_policy" {
  command = plan

  variables {
    name                      = "custom-vpc"
    cidr_block                = "10.0.0.0/16"
    flow_log_destination_type = "s3"
    flow_log_destination_arn  = "arn:aws:s3:::my-flow-log-bucket"
  }

  assert {
    condition     = length(aws_iam_role_policy.flow_log) == 0
    error_message = "Expected no IAM role policy when flow log destination is S3."
  }
}

run "test_custom_flow_log_s3_iam_role_output_null" {
  command = plan

  variables {
    name                      = "custom-vpc"
    cidr_block                = "10.0.0.0/16"
    flow_log_destination_type = "s3"
    flow_log_destination_arn  = "arn:aws:s3:::my-flow-log-bucket"
  }

  assert {
    condition     = output.flow_log_iam_role_arn == null
    error_message = "Expected flow_log_iam_role_arn output to be null when destination is S3."
  }

  assert {
    condition     = output.flow_log_cloudwatch_log_group_arn == null
    error_message = "Expected flow_log_cloudwatch_log_group_arn output to be null when destination is S3."
  }
}

################################################################################
# Flow Log with External CloudWatch Log Group
################################################################################

run "test_custom_flow_log_external_cloudwatch_skips_log_group" {
  command = plan

  variables {
    name                      = "custom-vpc"
    cidr_block                = "10.0.0.0/16"
    flow_log_destination_type = "cloud-watch-logs"
    flow_log_destination_arn  = "arn:aws:logs:us-east-1:123456789012:log-group:/custom/flow-logs"
    flow_log_iam_role_arn     = "arn:aws:iam::123456789012:role/custom-flow-log-role"
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.flow_log) == 0
    error_message = "Expected no log group when an external flow_log_destination_arn is provided."
  }

  assert {
    condition     = length(aws_iam_role.flow_log) == 0
    error_message = "Expected no IAM role when an external flow_log_iam_role_arn is provided."
  }

  assert {
    condition     = aws_flow_log.this[0].log_destination == "arn:aws:logs:us-east-1:123456789012:log-group:/custom/flow-logs"
    error_message = "Expected flow log to use the provided external CloudWatch Log Group ARN."
  }

  assert {
    condition     = aws_flow_log.this[0].iam_role_arn == "arn:aws:iam::123456789012:role/custom-flow-log-role"
    error_message = "Expected flow log to use the provided external IAM role ARN."
  }
}

################################################################################
# Minimal Configuration (everything disabled)
################################################################################

run "test_custom_minimal_vpc" {
  command = plan

  variables {
    name                          = "minimal-vpc"
    cidr_block                    = "192.168.0.0/24"
    create_igw                    = false
    manage_default_security_group = false
    flow_log_enabled              = false
  }

  assert {
    condition     = length(aws_internet_gateway.this) == 0
    error_message = "Expected no IGW in minimal configuration."
  }

  assert {
    condition     = length(aws_default_security_group.this) == 0
    error_message = "Expected no managed default SG in minimal configuration."
  }

  assert {
    condition     = length(aws_flow_log.this) == 0
    error_message = "Expected no flow log in minimal configuration."
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.flow_log) == 0
    error_message = "Expected no CloudWatch Log Group in minimal configuration."
  }

  assert {
    condition     = length(aws_iam_role.flow_log) == 0
    error_message = "Expected no IAM role in minimal configuration."
  }
}
