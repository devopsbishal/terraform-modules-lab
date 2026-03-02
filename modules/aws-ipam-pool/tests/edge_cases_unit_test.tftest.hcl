################################################################################
# Edge Cases Unit Tests — AWS IPAM Pool Module
#
# Tests boundary conditions, minimum/maximum valid values, and unusual
# but valid input combinations.
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
# Name Boundary Values
################################################################################

run "test_name_single_character" {
  command = plan

  variables {
    name          = "a"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.tags["Name"] == "a"
    error_message = "Expected single character name to be accepted."
  }
}

run "test_name_exactly_64_characters" {
  command = plan

  variables {
    name          = "a234567890123456789012345678901234567890123456789012345678901234"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.tags["Name"] == "a234567890123456789012345678901234567890123456789012345678901234"
    error_message = "Expected 64 character name to be accepted as the maximum length."
  }
}

run "test_name_all_hyphens" {
  command = plan

  variables {
    name          = "---"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.tags["Name"] == "---"
    error_message = "Expected name with only hyphens to be accepted (matches regex)."
  }
}

run "test_name_all_numbers" {
  command = plan

  variables {
    name          = "12345"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.tags["Name"] == "12345"
    error_message = "Expected name with only numbers to be accepted."
  }
}

run "test_name_mixed_case" {
  command = plan

  variables {
    name          = "My-Pool-123"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.tags["Name"] == "My-Pool-123"
    error_message = "Expected mixed-case name to be accepted."
  }
}

################################################################################
# Description Boundary Values
################################################################################

run "test_description_empty_string" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    description   = ""
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.description == ""
    error_message = "Expected empty description to be accepted."
  }
}

run "test_description_exactly_256_characters" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    description   = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.description == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    error_message = "Expected 256-character description to be accepted as the maximum length."
  }
}

################################################################################
# Empty cidrs map — valid for container pools
################################################################################

run "test_empty_cidrs_map" {
  command = plan

  variables {
    name          = "container-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    cidrs         = {}
  }

  assert {
    condition     = length(aws_vpc_ipam_pool_cidr.this) == 0
    error_message = "Expected no pool CIDRs when empty cidrs map is provided."
  }
}

################################################################################
# Allocation netmask boundary values
################################################################################

run "test_allocation_netmask_zero_ipv4" {
  command = plan

  variables {
    name                          = "test-pool"
    ipam_scope_id                 = "ipam-scope-0123456789abcdef0"
    address_family                = "ipv4"
    allocation_min_netmask_length = 0
    allocation_max_netmask_length = 32
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.allocation_min_netmask_length == 0
    error_message = "Expected netmask length 0 to be accepted."
  }
}

run "test_allocation_netmask_max_32_ipv4" {
  command = plan

  variables {
    name                          = "test-pool"
    ipam_scope_id                 = "ipam-scope-0123456789abcdef0"
    address_family                = "ipv4"
    allocation_min_netmask_length = 0
    allocation_max_netmask_length = 32
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.allocation_max_netmask_length == 32
    error_message = "Expected netmask length 32 to be accepted for IPv4."
  }
}

run "test_allocation_netmask_128_ipv6" {
  command = plan

  variables {
    name                          = "test-pool"
    ipam_scope_id                 = "ipam-scope-0123456789abcdef0"
    address_family                = "ipv6"
    allocation_min_netmask_length = 0
    allocation_max_netmask_length = 128
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.allocation_max_netmask_length == 128
    error_message = "Expected netmask length 128 to be accepted for IPv6."
  }
}

run "test_allocation_default_at_zero" {
  command = plan

  variables {
    name                              = "test-pool"
    ipam_scope_id                     = "ipam-scope-0123456789abcdef0"
    address_family                    = "ipv4"
    allocation_default_netmask_length = 0
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.allocation_default_netmask_length == 0
    error_message = "Expected allocation_default_netmask_length of 0 to be accepted."
  }
}

################################################################################
# CIDR netmask_length at boundaries
################################################################################

run "test_cidr_netmask_zero" {
  command = plan

  variables {
    name           = "test-pool"
    ipam_scope_id  = "ipam-scope-0123456789abcdef0"
    address_family = "ipv6"
    cidrs = {
      zero = { netmask_length = 0 }
    }
  }

  assert {
    condition     = aws_vpc_ipam_pool_cidr.this["zero"].netmask_length == 0
    error_message = "Expected netmask_length 0 to be accepted."
  }
}

run "test_cidr_netmask_128_ipv6" {
  command = plan

  variables {
    name           = "test-pool"
    ipam_scope_id  = "ipam-scope-0123456789abcdef0"
    address_family = "ipv6"
    cidrs = {
      max-v6 = { netmask_length = 128 }
    }
  }

  assert {
    condition     = aws_vpc_ipam_pool_cidr.this["max-v6"].netmask_length == 128
    error_message = "Expected netmask_length 128 to be accepted for IPv6."
  }
}

run "test_cidr_netmask_32_ipv4" {
  command = plan

  variables {
    name           = "test-pool"
    ipam_scope_id  = "ipam-scope-0123456789abcdef0"
    address_family = "ipv4"
    cidrs = {
      max-v4 = { netmask_length = 32 }
    }
  }

  assert {
    condition     = aws_vpc_ipam_pool_cidr.this["max-v4"].netmask_length == 32
    error_message = "Expected netmask_length 32 to be accepted for IPv4."
  }
}

################################################################################
# Tags — Edge Cases
################################################################################

run "test_empty_tags_map" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    tags          = {}
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.tags["Name"] == "test-pool"
    error_message = "Expected Name tag to still be set even with empty tags map."
  }
}

run "test_tags_with_many_entries" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    tags = {
      Environment = "production"
      Team        = "platform"
      CostCenter  = "12345"
      Project     = "terraform-lab"
      ManagedBy   = "terraform"
    }
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.tags["Name"] == "test-pool"
    error_message = "Expected Name tag to be preserved with many custom tags."
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.tags["CostCenter"] == "12345"
    error_message = "Expected CostCenter tag to be applied."
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.tags["ManagedBy"] == "terraform"
    error_message = "Expected ManagedBy tag to be applied."
  }
}

run "test_tags_name_override" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    tags = {
      Name = "custom-name"
    }
  }

  # var.tags is merged after the module's default Name tag, so user tag wins
  assert {
    condition     = aws_vpc_ipam_pool.this.tags["Name"] == "custom-name"
    error_message = "Expected user-provided Name tag to override the module's default Name tag."
  }
}

################################################################################
# Allocation resource tags — Empty and populated
################################################################################

run "test_allocation_resource_tags_empty" {
  command = plan

  variables {
    name                     = "test-pool"
    ipam_scope_id            = "ipam-scope-0123456789abcdef0"
    allocation_resource_tags = {}
  }

  assert {
    condition     = length(aws_vpc_ipam_pool.this.allocation_resource_tags) == 0
    error_message = "Expected empty allocation_resource_tags to be accepted."
  }
}

################################################################################
# IPv6 CIDRs — Various valid formats
################################################################################

run "test_ipv6_cidr_documentation_prefix" {
  command = plan

  variables {
    name           = "ipv6-pool"
    ipam_scope_id  = "ipam-scope-0123456789abcdef0"
    address_family = "ipv6"
    cidrs = {
      doc-prefix = { cidr = "2001:db8::/32" }
    }
  }

  assert {
    condition     = aws_vpc_ipam_pool_cidr.this["doc-prefix"].cidr == "2001:db8::/32"
    error_message = "Expected IPv6 documentation prefix CIDR to be accepted."
  }
}

################################################################################
# Pool with all optional fields set
################################################################################

run "test_fully_configured_child_pool" {
  command = plan

  variables {
    name                              = "full-config-pool"
    ipam_scope_id                     = "ipam-scope-0123456789abcdef0"
    address_family                    = "ipv4"
    description                       = "Fully configured child pool"
    source_ipam_pool_id               = "ipam-pool-0123456789abcdef0"
    locale                            = "us-east-1"
    auto_import                       = true
    cascade_delete                    = true
    aws_service                       = "ec2"
    allocation_min_netmask_length     = 16
    allocation_max_netmask_length     = 28
    allocation_default_netmask_length = 24
    allocation_resource_tags = {
      Environment = "production"
    }
    cidrs = {
      primary   = { cidr = "10.0.0.0/16" }
      secondary = { netmask_length = 16 }
    }
    tags = {
      Team = "platform"
    }
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.address_family == "ipv4"
    error_message = "Expected address_family to be 'ipv4'."
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.description == "Fully configured child pool"
    error_message = "Expected description to match."
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.source_ipam_pool_id == "ipam-pool-0123456789abcdef0"
    error_message = "Expected source_ipam_pool_id to be set."
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.locale == "us-east-1"
    error_message = "Expected locale to be us-east-1."
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.auto_import == true
    error_message = "Expected auto_import to be true."
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.cascade == true
    error_message = "Expected cascade to be true."
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.aws_service == "ec2"
    error_message = "Expected aws_service to be 'ec2'."
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.allocation_min_netmask_length == 16
    error_message = "Expected allocation_min_netmask_length to be 16."
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.allocation_max_netmask_length == 28
    error_message = "Expected allocation_max_netmask_length to be 28."
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.allocation_default_netmask_length == 24
    error_message = "Expected allocation_default_netmask_length to be 24."
  }

  assert {
    condition     = length(aws_vpc_ipam_pool_cidr.this) == 2
    error_message = "Expected 2 CIDRs to be provisioned."
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.tags["Name"] == "full-config-pool"
    error_message = "Expected Name tag to be set."
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.tags["Team"] == "platform"
    error_message = "Expected custom Team tag to be applied."
  }
}
