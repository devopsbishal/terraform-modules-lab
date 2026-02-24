################################################################################
# Edge Cases Unit Tests — AWS VPC Module
#
# Tests boundary conditions, minimum/maximum valid values, and unusual
# but valid input combinations.
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
# CIDR Block Boundary Values
################################################################################

run "test_cidr_prefix_exactly_16" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.this.cidr_block == "10.0.0.0/16"
    error_message = "Expected /16 CIDR to be accepted as the minimum prefix length."
  }
}

run "test_cidr_prefix_exactly_24" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/24"
  }

  assert {
    condition     = aws_vpc.this.cidr_block == "10.0.0.0/24"
    error_message = "Expected /24 CIDR to be accepted as the maximum prefix length."
  }
}

run "test_cidr_prefix_exactly_20" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "172.16.0.0/20"
  }

  assert {
    condition     = aws_vpc.this.cidr_block == "172.16.0.0/20"
    error_message = "Expected /20 CIDR to be accepted as a mid-range prefix length."
  }
}

run "test_cidr_rfc1918_class_c" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "192.168.1.0/24"
  }

  assert {
    condition     = aws_vpc.this.cidr_block == "192.168.1.0/24"
    error_message = "Expected 192.168.x.x/24 CIDR to be accepted."
  }
}

run "test_cidr_rfc1918_class_b" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "172.31.0.0/16"
  }

  assert {
    condition     = aws_vpc.this.cidr_block == "172.31.0.0/16"
    error_message = "Expected 172.31.0.0/16 CIDR to be accepted."
  }
}

################################################################################
# Name Boundary Values
################################################################################

run "test_name_single_character" {
  command = plan

  variables {
    name       = "a"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.this.tags["Name"] == "a"
    error_message = "Expected single character name to be accepted."
  }
}

run "test_name_exactly_46_characters" {
  command = plan

  variables {
    name       = "a23456789012345678901234567890123456789012345Z"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.this.tags["Name"] == "a23456789012345678901234567890123456789012345Z"
    error_message = "Expected 46 character name to be accepted as the maximum length."
  }
}

run "test_name_all_hyphens" {
  command = plan

  variables {
    name       = "---"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.this.tags["Name"] == "---"
    error_message = "Expected name with only hyphens to be accepted (matches regex)."
  }
}

run "test_name_all_numbers" {
  command = plan

  variables {
    name       = "12345"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.this.tags["Name"] == "12345"
    error_message = "Expected name with only numbers to be accepted."
  }
}

run "test_name_mixed_case" {
  command = plan

  variables {
    name       = "My-VPC-123"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.this.tags["Name"] == "My-VPC-123"
    error_message = "Expected mixed-case name to be accepted."
  }
}

################################################################################
# Empty Tags Map
################################################################################

run "test_empty_tags_map" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/16"
    tags       = {}
  }

  assert {
    condition     = aws_vpc.this.tags["Name"] == "test-vpc"
    error_message = "Expected Name tag to still be set even with empty tags map."
  }
}

################################################################################
# Retention Boundary Values (valid CloudWatch retention periods)
################################################################################

run "test_retention_zero_never_expire" {
  command = plan

  variables {
    name                                            = "test-vpc"
    cidr_block                                      = "10.0.0.0/16"
    flow_log_cloudwatch_log_group_retention_in_days = 0
  }

  assert {
    condition     = aws_cloudwatch_log_group.flow_log[0].retention_in_days == 0
    error_message = "Expected 0 (never expire) to be an accepted retention value."
  }
}

run "test_retention_one_day" {
  command = plan

  variables {
    name                                            = "test-vpc"
    cidr_block                                      = "10.0.0.0/16"
    flow_log_cloudwatch_log_group_retention_in_days = 1
  }

  assert {
    condition     = aws_cloudwatch_log_group.flow_log[0].retention_in_days == 1
    error_message = "Expected 1 day to be an accepted retention value."
  }
}

run "test_retention_maximum_3653_days" {
  command = plan

  variables {
    name                                            = "test-vpc"
    cidr_block                                      = "10.0.0.0/16"
    flow_log_cloudwatch_log_group_retention_in_days = 3653
  }

  assert {
    condition     = aws_cloudwatch_log_group.flow_log[0].retention_in_days == 3653
    error_message = "Expected 3653 (10 years) to be an accepted retention value."
  }
}

################################################################################
# All Boolean Flags Set to Non-Default Values
################################################################################

run "test_all_booleans_inverted" {
  command = plan

  variables {
    name                                 = "inverted-vpc"
    cidr_block                           = "10.0.0.0/16"
    create_igw                           = false
    enable_dns_hostnames                 = false
    enable_dns_support                   = false
    enable_network_address_usage_metrics = true
    flow_log_enabled                     = false
    manage_default_security_group        = false
    assign_generated_ipv6_cidr_block     = true
  }

  assert {
    condition     = aws_vpc.this.enable_dns_support == false
    error_message = "Expected enable_dns_support to be false."
  }

  assert {
    condition     = aws_vpc.this.enable_dns_hostnames == false
    error_message = "Expected enable_dns_hostnames to be false."
  }

  assert {
    condition     = aws_vpc.this.enable_network_address_usage_metrics == true
    error_message = "Expected enable_network_address_usage_metrics to be true."
  }

  assert {
    condition     = aws_vpc.this.assign_generated_ipv6_cidr_block == true
    error_message = "Expected assign_generated_ipv6_cidr_block to be true."
  }

  assert {
    condition     = length(aws_internet_gateway.this) == 0
    error_message = "Expected no IGW when create_igw is false."
  }

  assert {
    condition     = length(aws_default_security_group.this) == 0
    error_message = "Expected no managed default SG when manage_default_security_group is false."
  }

  assert {
    condition     = length(aws_flow_log.this) == 0
    error_message = "Expected no flow log when flow_log_enabled is false."
  }
}

################################################################################
# Resource Naming Propagation
################################################################################

run "test_name_propagates_to_all_resource_tags" {
  command = plan

  variables {
    name       = "naming-test"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.this.tags["Name"] == "naming-test"
    error_message = "Expected VPC Name tag to match var.name."
  }

  assert {
    condition     = aws_internet_gateway.this[0].tags["Name"] == "naming-test-igw"
    error_message = "Expected IGW Name tag to be 'naming-test-igw'."
  }

  assert {
    condition     = aws_default_security_group.this[0].tags["Name"] == "naming-test-default-sg"
    error_message = "Expected default SG Name tag to be 'naming-test-default-sg'."
  }

  assert {
    condition     = aws_flow_log.this[0].tags["Name"] == "naming-test-flow-log"
    error_message = "Expected flow log Name tag to be 'naming-test-flow-log'."
  }

  assert {
    condition     = aws_iam_role.flow_log[0].name == "naming-test-vpc-flow-log-role"
    error_message = "Expected IAM role name to be 'naming-test-vpc-flow-log-role'."
  }

  assert {
    condition     = aws_iam_role_policy.flow_log[0].name == "naming-test-vpc-flow-log-policy"
    error_message = "Expected IAM role policy name to be 'naming-test-vpc-flow-log-policy'."
  }
}

################################################################################
# Custom Tags Propagate to Sub-Resources
################################################################################

run "test_custom_tags_on_igw" {
  command = plan

  variables {
    name       = "tag-test"
    cidr_block = "10.0.0.0/16"
    tags = {
      Project = "terraform-lab"
    }
  }

  assert {
    condition     = aws_internet_gateway.this[0].tags["Project"] == "terraform-lab"
    error_message = "Expected custom tags to propagate to IGW."
  }

  assert {
    condition     = aws_internet_gateway.this[0].tags["Name"] == "tag-test-igw"
    error_message = "Expected IGW Name tag to be preserved alongside custom tags."
  }
}

run "test_custom_tags_on_flow_log" {
  command = plan

  variables {
    name       = "tag-test"
    cidr_block = "10.0.0.0/16"
    tags = {
      CostCenter = "12345"
    }
  }

  assert {
    condition     = aws_flow_log.this[0].tags["CostCenter"] == "12345"
    error_message = "Expected custom tags to propagate to flow log."
  }
}

run "test_custom_tags_on_iam_role" {
  command = plan

  variables {
    name       = "tag-test"
    cidr_block = "10.0.0.0/16"
    tags = {
      ManagedBy = "terraform"
    }
  }

  assert {
    condition     = aws_iam_role.flow_log[0].tags["ManagedBy"] == "terraform"
    error_message = "Expected custom tags to propagate to IAM role."
  }
}

run "test_custom_tags_on_cloudwatch_log_group" {
  command = plan

  variables {
    name       = "tag-test"
    cidr_block = "10.0.0.0/16"
    tags = {
      Environment = "production"
    }
  }

  assert {
    condition     = aws_cloudwatch_log_group.flow_log[0].tags["Environment"] == "production"
    error_message = "Expected custom tags to propagate to CloudWatch Log Group."
  }
}
