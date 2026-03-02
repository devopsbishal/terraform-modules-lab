################################################################################
# Custom Values Unit Tests — AWS IPAM Pool Module
#
# Validates that the module correctly applies non-default variable values
# and creates resources with the expected arguments.
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
# Pool with IPv6 address family
################################################################################

run "test_custom_ipv6_address_family" {
  command = plan

  variables {
    name           = "ipv6-pool"
    ipam_scope_id  = "ipam-scope-0123456789abcdef0"
    address_family = "ipv6"
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.address_family == "ipv6"
    error_message = "Expected address_family to be 'ipv6', got '${aws_vpc_ipam_pool.this.address_family}'."
  }
}

################################################################################
# Pool with custom description
################################################################################

run "test_custom_description" {
  command = plan

  variables {
    name          = "described-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    description   = "Production IPv4 address pool for us-east-1"
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.description == "Production IPv4 address pool for us-east-1"
    error_message = "Expected description to match provided value."
  }
}

################################################################################
# Pool with auto_import enabled
################################################################################

run "test_custom_auto_import_enabled" {
  command = plan

  variables {
    name          = "auto-import-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    auto_import   = true
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.auto_import == true
    error_message = "Expected auto_import to be true when explicitly set."
  }
}

################################################################################
# Pool with cascade delete enabled
################################################################################

run "test_custom_cascade_delete_enabled" {
  command = plan

  variables {
    name           = "cascade-pool"
    ipam_scope_id  = "ipam-scope-0123456789abcdef0"
    cascade_delete = true
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.cascade == true
    error_message = "Expected cascade to be true when cascade_delete is enabled."
  }
}

################################################################################
# Pool with aws_service set to "ec2"
################################################################################

run "test_custom_aws_service_ec2" {
  command = plan

  variables {
    name          = "ec2-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    aws_service   = "ec2"
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.aws_service == "ec2"
    error_message = "Expected aws_service to be 'ec2', got '${aws_vpc_ipam_pool.this.aws_service}'."
  }
}

################################################################################
# Pool with allocation guardrails
################################################################################

run "test_custom_allocation_guardrails" {
  command = plan

  variables {
    name                              = "guarded-pool"
    ipam_scope_id                     = "ipam-scope-0123456789abcdef0"
    allocation_min_netmask_length     = 16
    allocation_max_netmask_length     = 28
    allocation_default_netmask_length = 24
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
}

################################################################################
# Pool with allocation_resource_tags
################################################################################

run "test_custom_allocation_resource_tags" {
  command = plan

  variables {
    name          = "tagged-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    allocation_resource_tags = {
      Environment = "production"
      ManagedBy   = "terraform"
    }
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.allocation_resource_tags["Environment"] == "production"
    error_message = "Expected allocation_resource_tags to include Environment = production."
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.allocation_resource_tags["ManagedBy"] == "terraform"
    error_message = "Expected allocation_resource_tags to include ManagedBy = terraform."
  }
}

################################################################################
# Pool with explicit CIDR
################################################################################

run "test_custom_single_explicit_cidr" {
  command = plan

  variables {
    name          = "cidr-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    cidrs = {
      primary = {
        cidr = "10.0.0.0/8"
      }
    }
  }

  assert {
    condition     = length(aws_vpc_ipam_pool_cidr.this) == 1
    error_message = "Expected exactly 1 pool CIDR to be created."
  }

  assert {
    condition     = aws_vpc_ipam_pool_cidr.this["primary"].cidr == "10.0.0.0/8"
    error_message = "Expected CIDR to be '10.0.0.0/8'."
  }

  assert {
    condition     = aws_vpc_ipam_pool_cidr.this["primary"].netmask_length == null
    error_message = "Expected netmask_length to be null when explicit CIDR is used."
  }
}

################################################################################
# Pool with netmask_length CIDR (for child pools)
################################################################################

run "test_custom_single_netmask_cidr" {
  command = plan

  variables {
    name                = "child-pool"
    ipam_scope_id       = "ipam-scope-0123456789abcdef0"
    source_ipam_pool_id = "ipam-pool-0123456789abcdef0"
    locale              = "us-east-1"
    cidrs = {
      allocated = {
        netmask_length = 16
      }
    }
  }

  assert {
    condition     = length(aws_vpc_ipam_pool_cidr.this) == 1
    error_message = "Expected exactly 1 pool CIDR to be created."
  }

  assert {
    condition     = aws_vpc_ipam_pool_cidr.this["allocated"].netmask_length == 16
    error_message = "Expected netmask_length to be 16."
  }

  # Note: Cannot assert cidr == null in plan mode because cidr is a computed
  # attribute that is unknown until apply (IPAM assigns the CIDR from the
  # parent pool). This is a known plan-mode limitation.
}

################################################################################
# Pool with multiple CIDRs
################################################################################

run "test_custom_multiple_cidrs" {
  command = plan

  variables {
    name          = "multi-cidr-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    cidrs = {
      rfc1918-10  = { cidr = "10.0.0.0/8" }
      rfc1918-172 = { cidr = "172.16.0.0/12" }
      rfc1918-192 = { cidr = "192.168.0.0/16" }
    }
  }

  assert {
    condition     = length(aws_vpc_ipam_pool_cidr.this) == 3
    error_message = "Expected 3 pool CIDRs to be created, got ${length(aws_vpc_ipam_pool_cidr.this)}."
  }

  assert {
    condition     = aws_vpc_ipam_pool_cidr.this["rfc1918-10"].cidr == "10.0.0.0/8"
    error_message = "Expected rfc1918-10 CIDR to be '10.0.0.0/8'."
  }

  assert {
    condition     = aws_vpc_ipam_pool_cidr.this["rfc1918-172"].cidr == "172.16.0.0/12"
    error_message = "Expected rfc1918-172 CIDR to be '172.16.0.0/12'."
  }

  assert {
    condition     = aws_vpc_ipam_pool_cidr.this["rfc1918-192"].cidr == "192.168.0.0/16"
    error_message = "Expected rfc1918-192 CIDR to be '192.168.0.0/16'."
  }
}

################################################################################
# Top-level pool (no source_ipam_pool_id, no locale)
################################################################################

run "test_custom_top_level_pool" {
  command = plan

  variables {
    name          = "top-level-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    cidrs = {
      primary = { cidr = "10.0.0.0/8" }
    }
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.source_ipam_pool_id == null
    error_message = "Expected top-level pool to have no source_ipam_pool_id."
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.locale == null
    error_message = "Expected top-level pool to have no locale."
  }
}

################################################################################
# Child pool (with source_ipam_pool_id and locale)
################################################################################

run "test_custom_child_pool" {
  command = plan

  variables {
    name                = "child-pool-useast1"
    ipam_scope_id       = "ipam-scope-0123456789abcdef0"
    source_ipam_pool_id = "ipam-pool-0123456789abcdef0"
    locale              = "us-east-1"
    cidrs = {
      allocated = { netmask_length = 16 }
    }
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.source_ipam_pool_id == "ipam-pool-0123456789abcdef0"
    error_message = "Expected child pool to have source_ipam_pool_id set."
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.locale == "us-east-1"
    error_message = "Expected child pool locale to be 'us-east-1'."
  }
}

################################################################################
# Pool with public_ip_source
################################################################################

run "test_custom_public_ip_source_byoip" {
  command = plan

  variables {
    name             = "public-pool"
    ipam_scope_id    = "ipam-scope-0123456789abcdef0"
    address_family   = "ipv4"
    public_ip_source = "byoip"
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.public_ip_source == "byoip"
    error_message = "Expected public_ip_source to be 'byoip'."
  }
}

run "test_custom_public_ip_source_amazon" {
  command = plan

  variables {
    name             = "amazon-pool"
    ipam_scope_id    = "ipam-scope-0123456789abcdef0"
    address_family   = "ipv4"
    public_ip_source = "amazon"
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.public_ip_source == "amazon"
    error_message = "Expected public_ip_source to be 'amazon'."
  }
}

################################################################################
# Pool with publicly_advertisable (IPv6 only)
################################################################################

run "test_custom_publicly_advertisable_ipv6" {
  command = plan

  variables {
    name                  = "advertisable-pool"
    ipam_scope_id         = "ipam-scope-0123456789abcdef0"
    address_family        = "ipv6"
    publicly_advertisable = true
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.publicly_advertisable == true
    error_message = "Expected publicly_advertisable to be true for IPv6 pool."
  }
}

################################################################################
# Tags merge correctly
################################################################################

run "test_custom_tags_merged" {
  command = plan

  variables {
    name          = "tagged-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    tags = {
      Environment = "production"
      Team        = "platform"
    }
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.tags["Name"] == "tagged-pool"
    error_message = "Expected Name tag to be preserved when custom tags are provided."
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.tags["Environment"] == "production"
    error_message = "Expected custom Environment tag to be applied."
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.tags["Team"] == "platform"
    error_message = "Expected custom Team tag to be applied."
  }
}

################################################################################
# Pool with locale set to various valid regions
################################################################################

run "test_custom_locale_eu_west" {
  command = plan

  variables {
    name                = "eu-pool"
    ipam_scope_id       = "ipam-scope-0123456789abcdef0"
    source_ipam_pool_id = "ipam-pool-0123456789abcdef0"
    locale              = "eu-west-1"
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.locale == "eu-west-1"
    error_message = "Expected locale to be 'eu-west-1'."
  }
}

run "test_custom_locale_ap_southeast" {
  command = plan

  variables {
    name                = "ap-pool"
    ipam_scope_id       = "ipam-scope-0123456789abcdef0"
    source_ipam_pool_id = "ipam-pool-0123456789abcdef0"
    locale              = "ap-southeast-1"
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.locale == "ap-southeast-1"
    error_message = "Expected locale to be 'ap-southeast-1'."
  }
}

run "test_custom_locale_govcloud" {
  command = plan

  variables {
    name                = "gov-pool"
    ipam_scope_id       = "ipam-scope-0123456789abcdef0"
    source_ipam_pool_id = "ipam-pool-0123456789abcdef0"
    locale              = "us-gov-west-1"
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.locale == "us-gov-west-1"
    error_message = "Expected locale to accept GovCloud region 'us-gov-west-1'."
  }
}

################################################################################
# Mixed CIDRs — some explicit, some netmask_length
################################################################################

run "test_custom_mixed_cidrs" {
  command = plan

  variables {
    name                = "mixed-pool"
    ipam_scope_id       = "ipam-scope-0123456789abcdef0"
    source_ipam_pool_id = "ipam-pool-0123456789abcdef0"
    locale              = "us-east-1"
    cidrs = {
      explicit  = { cidr = "10.0.0.0/16" }
      allocated = { netmask_length = 16 }
    }
  }

  assert {
    condition     = length(aws_vpc_ipam_pool_cidr.this) == 2
    error_message = "Expected 2 pool CIDRs (1 explicit + 1 allocated)."
  }

  assert {
    condition     = aws_vpc_ipam_pool_cidr.this["explicit"].cidr == "10.0.0.0/16"
    error_message = "Expected explicit CIDR to be '10.0.0.0/16'."
  }

  assert {
    condition     = aws_vpc_ipam_pool_cidr.this["allocated"].netmask_length == 16
    error_message = "Expected allocated netmask_length to be 16."
  }
}
