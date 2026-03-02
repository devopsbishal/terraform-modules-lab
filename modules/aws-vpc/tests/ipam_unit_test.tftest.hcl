################################################################################
# IPAM Unit Tests — AWS VPC Module
#
# Tests IPv4 IPAM resource creation, IPAM with other features (IGW, SG, flow
# logs, DNS, tags), IPAM outputs, and boundary values for netmask lengths.
#
# NOTE: IPv6 IPAM and dual-stack IPAM tests are in a separate file
# (ipam_ipv6_unit_test.tftest.hcl) because they are blocked by a module bug
# where assign_generated_ipv6_cidr_block is always passed to the VPC resource,
# triggering an AWS provider schema conflict with ipv6_ipam_pool_id.
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
# IPv4 IPAM Mode — Basic Resource Creation
################################################################################

run "test_ipv4_ipam_pool_id_set_on_vpc" {
  command = plan

  variables {
    name                = "ipam-vpc"
    ipv4_ipam_pool_id   = "ipam-pool-0123456789abcdef0"
    ipv4_netmask_length = 20
    flow_log_enabled    = false
  }

  assert {
    condition     = aws_vpc.this.ipv4_ipam_pool_id == "ipam-pool-0123456789abcdef0"
    error_message = "Expected VPC ipv4_ipam_pool_id to be 'ipam-pool-0123456789abcdef0', got '${aws_vpc.this.ipv4_ipam_pool_id}'."
  }
}

run "test_ipv4_ipam_netmask_length_set_on_vpc" {
  command = plan

  variables {
    name                = "ipam-vpc"
    ipv4_ipam_pool_id   = "ipam-pool-0123456789abcdef0"
    ipv4_netmask_length = 20
    flow_log_enabled    = false
  }

  assert {
    condition     = aws_vpc.this.ipv4_netmask_length == 20
    error_message = "Expected VPC ipv4_netmask_length to be 20, got ${aws_vpc.this.ipv4_netmask_length}."
  }
}

# NOTE: Cannot assert cidr_block == null in plan mode because cidr_block is a
# computed attribute. When the input is null, the plan shows it as "(known after
# apply)" which is unknown, not null. This is a Terraform test framework
# limitation with plan-mode assertions on computed attributes.

run "test_ipv4_ipam_mode_no_ipv6" {
  command = plan

  variables {
    name                = "ipam-vpc"
    ipv4_ipam_pool_id   = "ipam-pool-0123456789abcdef0"
    ipv4_netmask_length = 20
    flow_log_enabled    = false
  }

  assert {
    condition     = aws_vpc.this.assign_generated_ipv6_cidr_block == false
    error_message = "Expected assign_generated_ipv6_cidr_block to be false in IPv4-only IPAM mode."
  }

  assert {
    condition     = aws_vpc.this.ipv6_ipam_pool_id == null
    error_message = "Expected ipv6_ipam_pool_id to be null in IPv4-only IPAM mode."
  }

  assert {
    condition     = aws_vpc.this.ipv6_netmask_length == null
    error_message = "Expected ipv6_netmask_length to be null in IPv4-only IPAM mode."
  }
}

run "test_ipv4_ipam_mode_name_tag" {
  command = plan

  variables {
    name                = "ipam-vpc"
    ipv4_ipam_pool_id   = "ipam-pool-0123456789abcdef0"
    ipv4_netmask_length = 20
    flow_log_enabled    = false
  }

  assert {
    condition     = aws_vpc.this.tags["Name"] == "ipam-vpc"
    error_message = "Expected VPC Name tag to be 'ipam-vpc' in IPAM mode."
  }
}

################################################################################
# IPv4 IPAM Mode with All Features Enabled
################################################################################

run "test_ipv4_ipam_with_igw" {
  command = plan

  variables {
    name                = "ipam-full"
    ipv4_ipam_pool_id   = "ipam-pool-0123456789abcdef0"
    ipv4_netmask_length = 16
    create_igw          = true
  }

  assert {
    condition     = length(aws_internet_gateway.this) == 1
    error_message = "Expected IGW to be created in IPAM mode with create_igw = true."
  }

  assert {
    condition     = aws_internet_gateway.this[0].tags["Name"] == "ipam-full-igw"
    error_message = "Expected IGW Name tag to be 'ipam-full-igw'."
  }
}

run "test_ipv4_ipam_with_default_sg" {
  command = plan

  variables {
    name                          = "ipam-full"
    ipv4_ipam_pool_id             = "ipam-pool-0123456789abcdef0"
    ipv4_netmask_length           = 16
    manage_default_security_group = true
  }

  assert {
    condition     = length(aws_default_security_group.this) == 1
    error_message = "Expected default SG to be managed in IPAM mode."
  }
}

run "test_ipv4_ipam_with_flow_logs" {
  command = plan

  variables {
    name                = "ipam-full"
    ipv4_ipam_pool_id   = "ipam-pool-0123456789abcdef0"
    ipv4_netmask_length = 16
    flow_log_enabled    = true
  }

  assert {
    condition     = length(aws_flow_log.this) == 1
    error_message = "Expected flow log to be created in IPAM mode with flow_log_enabled = true."
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.flow_log) == 1
    error_message = "Expected CloudWatch Log Group to be created in IPAM mode with default flow log settings."
  }

  assert {
    condition     = length(aws_iam_role.flow_log) == 1
    error_message = "Expected IAM role to be created in IPAM mode with default flow log settings."
  }
}

run "test_ipv4_ipam_with_dns_settings" {
  command = plan

  variables {
    name                 = "ipam-dns"
    ipv4_ipam_pool_id    = "ipam-pool-0123456789abcdef0"
    ipv4_netmask_length  = 20
    enable_dns_support   = true
    enable_dns_hostnames = true
    flow_log_enabled     = false
  }

  assert {
    condition     = aws_vpc.this.enable_dns_support == true
    error_message = "Expected enable_dns_support to be true in IPAM mode."
  }

  assert {
    condition     = aws_vpc.this.enable_dns_hostnames == true
    error_message = "Expected enable_dns_hostnames to be true in IPAM mode."
  }
}

run "test_ipv4_ipam_with_custom_tags" {
  command = plan

  variables {
    name                = "ipam-tagged"
    ipv4_ipam_pool_id   = "ipam-pool-0123456789abcdef0"
    ipv4_netmask_length = 20
    flow_log_enabled    = false
    tags = {
      Environment = "staging"
      ManagedBy   = "terraform"
    }
  }

  assert {
    condition     = aws_vpc.this.tags["Environment"] == "staging"
    error_message = "Expected custom Environment tag to be applied in IPAM mode."
  }

  assert {
    condition     = aws_vpc.this.tags["ManagedBy"] == "terraform"
    error_message = "Expected custom ManagedBy tag to be applied in IPAM mode."
  }

  assert {
    condition     = aws_vpc.this.tags["Name"] == "ipam-tagged"
    error_message = "Expected Name tag to be preserved alongside custom tags in IPAM mode."
  }
}

################################################################################
# IPAM Output Tests
################################################################################

run "test_output_ipv4_ipam_pool_id_when_set" {
  command = plan

  variables {
    name                = "ipam-output"
    ipv4_ipam_pool_id   = "ipam-pool-0123456789abcdef0"
    ipv4_netmask_length = 20
    flow_log_enabled    = false
  }

  assert {
    condition     = output.ipv4_ipam_pool_id == "ipam-pool-0123456789abcdef0"
    error_message = "Expected ipv4_ipam_pool_id output to match input 'ipam-pool-0123456789abcdef0', got '${output.ipv4_ipam_pool_id}'."
  }
}

run "test_output_ipv4_ipam_pool_id_null_without_ipam" {
  command = plan

  variables {
    name             = "non-ipam"
    cidr_block       = "10.0.0.0/16"
    flow_log_enabled = false
  }

  assert {
    condition     = output.ipv4_ipam_pool_id == null
    error_message = "Expected ipv4_ipam_pool_id output to be null when not using IPAM."
  }
}

run "test_output_ipv6_ipam_pool_id_null_without_ipam" {
  command = plan

  variables {
    name             = "non-ipam"
    cidr_block       = "10.0.0.0/16"
    flow_log_enabled = false
  }

  assert {
    condition     = output.ipv6_ipam_pool_id == null
    error_message = "Expected ipv6_ipam_pool_id output to be null when not using IPv6 IPAM."
  }
}

################################################################################
# IPAM Edge Cases — IPv4 Netmask Boundary Values
################################################################################

run "test_ipv4_netmask_length_min_16" {
  command = plan

  variables {
    name                = "ipam-min"
    ipv4_ipam_pool_id   = "ipam-pool-0123456789abcdef0"
    ipv4_netmask_length = 16
    flow_log_enabled    = false
  }

  assert {
    condition     = aws_vpc.this.ipv4_netmask_length == 16
    error_message = "Expected ipv4_netmask_length of 16 (minimum) to be accepted."
  }
}

run "test_ipv4_netmask_length_max_28" {
  command = plan

  variables {
    name                = "ipam-max"
    ipv4_ipam_pool_id   = "ipam-pool-0123456789abcdef0"
    ipv4_netmask_length = 28
    flow_log_enabled    = false
  }

  assert {
    condition     = aws_vpc.this.ipv4_netmask_length == 28
    error_message = "Expected ipv4_netmask_length of 28 (maximum) to be accepted."
  }
}

################################################################################
# IPAM Mode with assign_generated_ipv6_cidr_block = false (explicit no-op)
################################################################################

run "test_ipv4_ipam_with_ipv6_generated_explicitly_false" {
  command = plan

  variables {
    name                             = "ipam-no-v6"
    ipv4_ipam_pool_id                = "ipam-pool-0123456789abcdef0"
    ipv4_netmask_length              = 20
    assign_generated_ipv6_cidr_block = false
    flow_log_enabled                 = false
  }

  assert {
    condition     = aws_vpc.this.assign_generated_ipv6_cidr_block == false
    error_message = "Expected assign_generated_ipv6_cidr_block to be false when explicitly set in IPAM mode."
  }

  assert {
    condition     = aws_vpc.this.ipv4_ipam_pool_id == "ipam-pool-0123456789abcdef0"
    error_message = "Expected IPAM configuration to work with assign_generated_ipv6_cidr_block explicitly false."
  }
}
