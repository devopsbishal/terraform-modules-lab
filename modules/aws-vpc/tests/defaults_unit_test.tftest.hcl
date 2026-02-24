################################################################################
# Defaults Unit Tests — AWS VPC Module
#
# Validates that the module produces a correct plan when only required
# variables (name, cidr_block) are provided and all defaults apply.
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
# VPC Core Defaults
################################################################################

run "test_default_vpc_cidr_block" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.this.cidr_block == "10.0.0.0/16"
    error_message = "Expected VPC cidr_block to be '10.0.0.0/16', got '${aws_vpc.this.cidr_block}'."
  }
}

run "test_default_dns_support_enabled" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.this.enable_dns_support == true
    error_message = "Expected enable_dns_support to default to true."
  }
}

run "test_default_dns_hostnames_enabled" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.this.enable_dns_hostnames == true
    error_message = "Expected enable_dns_hostnames to default to true."
  }
}

run "test_default_instance_tenancy" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.this.instance_tenancy == "default"
    error_message = "Expected instance_tenancy to default to 'default', got '${aws_vpc.this.instance_tenancy}'."
  }
}

run "test_default_ipv6_disabled" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.this.assign_generated_ipv6_cidr_block == false
    error_message = "Expected assign_generated_ipv6_cidr_block to default to false."
  }
}

run "test_default_nau_metrics_disabled" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.this.enable_network_address_usage_metrics == false
    error_message = "Expected enable_network_address_usage_metrics to default to false."
  }
}

run "test_default_name_tag" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.this.tags["Name"] == "test-vpc"
    error_message = "Expected VPC Name tag to be 'test-vpc', got '${aws_vpc.this.tags["Name"]}'."
  }
}

################################################################################
# Internet Gateway Defaults
################################################################################

run "test_default_igw_created" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = length(aws_internet_gateway.this) == 1
    error_message = "Expected IGW to be created by default (create_igw defaults to true)."
  }
}

run "test_default_igw_name_tag" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = aws_internet_gateway.this[0].tags["Name"] == "test-vpc-igw"
    error_message = "Expected IGW Name tag to be 'test-vpc-igw', got '${aws_internet_gateway.this[0].tags["Name"]}'."
  }
}

################################################################################
# Default Security Group Defaults
################################################################################

run "test_default_security_group_managed" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = length(aws_default_security_group.this) == 1
    error_message = "Expected default security group to be managed (manage_default_security_group defaults to true)."
  }
}

run "test_default_security_group_name_tag" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = aws_default_security_group.this[0].tags["Name"] == "test-vpc-default-sg"
    error_message = "Expected default SG Name tag to be 'test-vpc-default-sg', got '${aws_default_security_group.this[0].tags["Name"]}'."
  }
}

################################################################################
# Flow Log Defaults
################################################################################

run "test_default_flow_log_enabled" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = length(aws_flow_log.this) == 1
    error_message = "Expected flow log to be created by default (flow_log_enabled defaults to true)."
  }
}

run "test_default_flow_log_destination_type" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = aws_flow_log.this[0].log_destination_type == "cloud-watch-logs"
    error_message = "Expected flow log destination type to default to 'cloud-watch-logs', got '${aws_flow_log.this[0].log_destination_type}'."
  }
}

run "test_default_flow_log_traffic_type" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = aws_flow_log.this[0].traffic_type == "ALL"
    error_message = "Expected flow log traffic type to default to 'ALL', got '${aws_flow_log.this[0].traffic_type}'."
  }
}

run "test_default_flow_log_aggregation_interval" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = aws_flow_log.this[0].max_aggregation_interval == 600
    error_message = "Expected flow log max_aggregation_interval to default to 600, got ${aws_flow_log.this[0].max_aggregation_interval}."
  }
}

run "test_default_flow_log_name_tag" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = aws_flow_log.this[0].tags["Name"] == "test-vpc-flow-log"
    error_message = "Expected flow log Name tag to be 'test-vpc-flow-log', got '${aws_flow_log.this[0].tags["Name"]}'."
  }
}

################################################################################
# CloudWatch Log Group Defaults
################################################################################

run "test_default_cloudwatch_log_group_created" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.flow_log) == 1
    error_message = "Expected CloudWatch Log Group to be created when flow logs default to cloud-watch-logs destination."
  }
}

run "test_default_cloudwatch_log_group_retention" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = aws_cloudwatch_log_group.flow_log[0].retention_in_days == 30
    error_message = "Expected CloudWatch Log Group retention to default to 30 days, got ${aws_cloudwatch_log_group.flow_log[0].retention_in_days}."
  }
}

run "test_default_cloudwatch_log_group_no_kms" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = aws_cloudwatch_log_group.flow_log[0].kms_key_id == null
    error_message = "Expected CloudWatch Log Group kms_key_id to default to null."
  }
}

################################################################################
# IAM Role Defaults
################################################################################

run "test_default_iam_role_created" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = length(aws_iam_role.flow_log) == 1
    error_message = "Expected IAM role to be created when flow logs use cloud-watch-logs destination."
  }
}

run "test_default_iam_role_name" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = aws_iam_role.flow_log[0].name == "test-vpc-vpc-flow-log-role"
    error_message = "Expected IAM role name to be 'test-vpc-vpc-flow-log-role', got '${aws_iam_role.flow_log[0].name}'."
  }
}

run "test_default_iam_role_policy_created" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = length(aws_iam_role_policy.flow_log) == 1
    error_message = "Expected IAM role policy to be created when flow logs use cloud-watch-logs destination."
  }
}

run "test_default_iam_role_policy_name" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = aws_iam_role_policy.flow_log[0].name == "test-vpc-vpc-flow-log-policy"
    error_message = "Expected IAM role policy name to be 'test-vpc-vpc-flow-log-policy', got '${aws_iam_role_policy.flow_log[0].name}'."
  }
}

################################################################################
# Output Defaults
################################################################################

run "test_default_outputs_populated" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = output.vpc_cidr_block == "10.0.0.0/16"
    error_message = "Expected vpc_cidr_block output to be '10.0.0.0/16', got '${output.vpc_cidr_block}'."
  }
}
