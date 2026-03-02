################################################################################
# Defaults Unit Tests — AWS IPAM Pool Module
#
# Validates that the module produces a correct plan when only required
# variables (name, ipam_scope_id) are provided and all defaults apply.
################################################################################

mock_provider "aws" {
  mock_resource "aws_vpc_ipam_pool" {
    defaults = {
      id    = "ipam-pool-mock0123456789abcdef"
      arn   = "arn:aws:ec2:us-east-1:123456789012:ipam-pool/ipam-pool-mock0123456789abcdef"
      state = "create-complete"
    }
  }
  mock_resource "aws_vpc_ipam_pool_cidr" {
    defaults = {
      ipam_pool_cidr_id = "ipam-pool-cidr-mock0123456789"
      cidr              = "10.0.0.0/8"
    }
  }
}

################################################################################
# IPAM Pool Core Defaults
################################################################################

run "test_default_address_family" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.address_family == "ipv4"
    error_message = "Expected address_family to default to 'ipv4', got '${aws_vpc_ipam_pool.this.address_family}'."
  }
}

run "test_default_auto_import" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.auto_import == false
    error_message = "Expected auto_import to default to false."
  }
}

run "test_default_cascade_delete" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.cascade == false
    error_message = "Expected cascade to default to false."
  }
}

run "test_default_description_empty" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.description == ""
    error_message = "Expected description to default to empty string, got '${aws_vpc_ipam_pool.this.description}'."
  }
}

run "test_default_publicly_advertisable" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.publicly_advertisable == false
    error_message = "Expected publicly_advertisable to default to false."
  }
}

run "test_default_allocation_netmask_lengths_null" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.allocation_default_netmask_length == null
    error_message = "Expected allocation_default_netmask_length to default to null."
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.allocation_max_netmask_length == null
    error_message = "Expected allocation_max_netmask_length to default to null."
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.allocation_min_netmask_length == null
    error_message = "Expected allocation_min_netmask_length to default to null."
  }
}

run "test_default_optional_ids_null" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.source_ipam_pool_id == null
    error_message = "Expected source_ipam_pool_id to default to null."
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.locale == null
    error_message = "Expected locale to default to null."
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.public_ip_source == null
    error_message = "Expected public_ip_source to default to null."
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.aws_service == null
    error_message = "Expected aws_service to default to null."
  }
}

run "test_default_ipam_scope_id_set" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.ipam_scope_id == "ipam-scope-0123456789abcdef0"
    error_message = "Expected ipam_scope_id to be set to the provided value."
  }
}

################################################################################
# Conditional Resources — Defaults should NOT create CIDRs
################################################################################

run "test_default_no_pool_cidrs" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
  }

  assert {
    condition     = length(aws_vpc_ipam_pool_cidr.this) == 0
    error_message = "Expected no pool CIDRs to be created by default (empty cidrs map)."
  }
}

################################################################################
# Tags — Default Name tag
################################################################################

run "test_default_name_tag" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.tags["Name"] == "test-pool"
    error_message = "Expected Name tag to be 'test-pool', got '${aws_vpc_ipam_pool.this.tags["Name"]}'."
  }
}

################################################################################
# Output Defaults
################################################################################

run "test_default_pool_cidrs_output_empty" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
  }

  assert {
    condition     = length(output.pool_cidrs) == 0
    error_message = "Expected pool_cidrs output to be empty when no CIDRs are provisioned."
  }
}

run "test_default_pool_cidr_ids_output_empty" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
  }

  assert {
    condition     = length(output.pool_cidr_ids) == 0
    error_message = "Expected pool_cidr_ids output to be empty when no CIDRs are provisioned."
  }
}
