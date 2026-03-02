################################################################################
# Precondition Unit Tests — AWS IPAM Pool Module
#
# Tests lifecycle precondition blocks that enforce cross-variable constraints.
# These are runtime checks (not variable validations), so they use
# expect_failures on the resource rather than the variable.
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
# publicly_advertisable = true requires address_family = "ipv6"
################################################################################

run "test_reject_publicly_advertisable_with_ipv4" {
  command = plan

  variables {
    name                  = "test-pool"
    ipam_scope_id         = "ipam-scope-0123456789abcdef0"
    address_family        = "ipv4"
    publicly_advertisable = true
  }

  expect_failures = [aws_vpc_ipam_pool.this]
}

run "test_accept_publicly_advertisable_with_ipv6" {
  command = plan

  variables {
    name                  = "test-pool"
    ipam_scope_id         = "ipam-scope-0123456789abcdef0"
    address_family        = "ipv6"
    publicly_advertisable = true
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.publicly_advertisable == true
    error_message = "Expected publicly_advertisable to be accepted with IPv6 address family."
  }
}

################################################################################
# public_ip_source requires address_family = "ipv4"
################################################################################

run "test_reject_public_ip_source_with_ipv6" {
  command = plan

  variables {
    name             = "test-pool"
    ipam_scope_id    = "ipam-scope-0123456789abcdef0"
    address_family   = "ipv6"
    public_ip_source = "amazon"
  }

  expect_failures = [aws_vpc_ipam_pool.this]
}

run "test_accept_public_ip_source_with_ipv4" {
  command = plan

  variables {
    name             = "test-pool"
    ipam_scope_id    = "ipam-scope-0123456789abcdef0"
    address_family   = "ipv4"
    public_ip_source = "amazon"
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.public_ip_source == "amazon"
    error_message = "Expected public_ip_source to be accepted with IPv4 address family."
  }
}

run "test_reject_public_ip_source_byoip_with_ipv6" {
  command = plan

  variables {
    name             = "test-pool"
    ipam_scope_id    = "ipam-scope-0123456789abcdef0"
    address_family   = "ipv6"
    public_ip_source = "byoip"
  }

  expect_failures = [aws_vpc_ipam_pool.this]
}

################################################################################
# allocation_min_netmask_length must be <= allocation_max_netmask_length
################################################################################

run "test_reject_min_greater_than_max_netmask" {
  command = plan

  variables {
    name                          = "test-pool"
    ipam_scope_id                 = "ipam-scope-0123456789abcdef0"
    allocation_min_netmask_length = 28
    allocation_max_netmask_length = 16
  }

  expect_failures = [aws_vpc_ipam_pool.this]
}

run "test_accept_min_equal_to_max_netmask" {
  command = plan

  variables {
    name                          = "test-pool"
    ipam_scope_id                 = "ipam-scope-0123456789abcdef0"
    allocation_min_netmask_length = 24
    allocation_max_netmask_length = 24
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.allocation_min_netmask_length == 24
    error_message = "Expected min == max to be accepted."
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.allocation_max_netmask_length == 24
    error_message = "Expected min == max to be accepted."
  }
}

run "test_accept_min_less_than_max_netmask" {
  command = plan

  variables {
    name                          = "test-pool"
    ipam_scope_id                 = "ipam-scope-0123456789abcdef0"
    allocation_min_netmask_length = 16
    allocation_max_netmask_length = 28
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.allocation_min_netmask_length == 16
    error_message = "Expected min < max to be accepted."
  }
}

################################################################################
# allocation_default_netmask_length must be between min and max (inclusive)
################################################################################

run "test_reject_default_netmask_below_min" {
  command = plan

  variables {
    name                              = "test-pool"
    ipam_scope_id                     = "ipam-scope-0123456789abcdef0"
    allocation_min_netmask_length     = 16
    allocation_max_netmask_length     = 28
    allocation_default_netmask_length = 8
  }

  expect_failures = [aws_vpc_ipam_pool.this]
}

run "test_reject_default_netmask_above_max" {
  command = plan

  variables {
    name                              = "test-pool"
    ipam_scope_id                     = "ipam-scope-0123456789abcdef0"
    allocation_min_netmask_length     = 16
    allocation_max_netmask_length     = 28
    allocation_default_netmask_length = 30
  }

  expect_failures = [aws_vpc_ipam_pool.this]
}

run "test_accept_default_netmask_at_min_boundary" {
  command = plan

  variables {
    name                              = "test-pool"
    ipam_scope_id                     = "ipam-scope-0123456789abcdef0"
    allocation_min_netmask_length     = 16
    allocation_max_netmask_length     = 28
    allocation_default_netmask_length = 16
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.allocation_default_netmask_length == 16
    error_message = "Expected default at min boundary to be accepted."
  }
}

run "test_accept_default_netmask_at_max_boundary" {
  command = plan

  variables {
    name                              = "test-pool"
    ipam_scope_id                     = "ipam-scope-0123456789abcdef0"
    allocation_min_netmask_length     = 16
    allocation_max_netmask_length     = 28
    allocation_default_netmask_length = 28
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.allocation_default_netmask_length == 28
    error_message = "Expected default at max boundary to be accepted."
  }
}

run "test_accept_default_netmask_with_only_min_set" {
  command = plan

  variables {
    name                              = "test-pool"
    ipam_scope_id                     = "ipam-scope-0123456789abcdef0"
    allocation_min_netmask_length     = 16
    allocation_default_netmask_length = 24
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.allocation_default_netmask_length == 24
    error_message = "Expected default above min (with no max) to be accepted."
  }
}

run "test_accept_default_netmask_with_only_max_set" {
  command = plan

  variables {
    name                              = "test-pool"
    ipam_scope_id                     = "ipam-scope-0123456789abcdef0"
    allocation_max_netmask_length     = 28
    allocation_default_netmask_length = 24
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.allocation_default_netmask_length == 24
    error_message = "Expected default below max (with no min) to be accepted."
  }
}

run "test_reject_default_netmask_below_min_no_max" {
  command = plan

  variables {
    name                              = "test-pool"
    ipam_scope_id                     = "ipam-scope-0123456789abcdef0"
    allocation_min_netmask_length     = 16
    allocation_default_netmask_length = 8
  }

  expect_failures = [aws_vpc_ipam_pool.this]
}

run "test_reject_default_netmask_above_max_no_min" {
  command = plan

  variables {
    name                              = "test-pool"
    ipam_scope_id                     = "ipam-scope-0123456789abcdef0"
    allocation_max_netmask_length     = 28
    allocation_default_netmask_length = 30
  }

  expect_failures = [aws_vpc_ipam_pool.this]
}

################################################################################
# IPv4 pool: netmask lengths must be <= 32
################################################################################

run "test_reject_ipv4_allocation_min_netmask_over_32" {
  command = plan

  variables {
    name                          = "test-pool"
    ipam_scope_id                 = "ipam-scope-0123456789abcdef0"
    address_family                = "ipv4"
    allocation_min_netmask_length = 33
  }

  expect_failures = [aws_vpc_ipam_pool.this]
}

run "test_reject_ipv4_allocation_max_netmask_over_32" {
  command = plan

  variables {
    name                          = "test-pool"
    ipam_scope_id                 = "ipam-scope-0123456789abcdef0"
    address_family                = "ipv4"
    allocation_max_netmask_length = 64
  }

  expect_failures = [aws_vpc_ipam_pool.this]
}

run "test_reject_ipv4_allocation_default_netmask_over_32" {
  command = plan

  variables {
    name                              = "test-pool"
    ipam_scope_id                     = "ipam-scope-0123456789abcdef0"
    address_family                    = "ipv4"
    allocation_default_netmask_length = 48
  }

  expect_failures = [aws_vpc_ipam_pool.this]
}

run "test_reject_ipv4_cidr_netmask_length_over_32" {
  command = plan

  variables {
    name           = "test-pool"
    ipam_scope_id  = "ipam-scope-0123456789abcdef0"
    address_family = "ipv4"
    cidrs = {
      oversized = { netmask_length = 48 }
    }
  }

  expect_failures = [aws_vpc_ipam_pool.this]
}

run "test_accept_ipv6_netmask_length_over_32" {
  command = plan

  variables {
    name                          = "test-pool"
    ipam_scope_id                 = "ipam-scope-0123456789abcdef0"
    address_family                = "ipv6"
    allocation_min_netmask_length = 48
    allocation_max_netmask_length = 64
  }

  assert {
    condition     = aws_vpc_ipam_pool.this.allocation_min_netmask_length == 48
    error_message = "Expected IPv6 pool to accept netmask lengths > 32."
  }
}

################################################################################
# CIDR-to-address-family mismatch
################################################################################

run "test_reject_ipv6_cidr_in_ipv4_pool" {
  command = plan

  variables {
    name           = "test-pool"
    ipam_scope_id  = "ipam-scope-0123456789abcdef0"
    address_family = "ipv4"
    cidrs = {
      wrong-family = { cidr = "2001:db8::/32" }
    }
  }

  expect_failures = [aws_vpc_ipam_pool.this]
}

run "test_reject_ipv4_cidr_in_ipv6_pool" {
  command = plan

  variables {
    name           = "test-pool"
    ipam_scope_id  = "ipam-scope-0123456789abcdef0"
    address_family = "ipv6"
    cidrs = {
      wrong-family = { cidr = "10.0.0.0/8" }
    }
  }

  expect_failures = [aws_vpc_ipam_pool.this]
}

run "test_accept_ipv4_cidr_in_ipv4_pool" {
  command = plan

  variables {
    name           = "test-pool"
    ipam_scope_id  = "ipam-scope-0123456789abcdef0"
    address_family = "ipv4"
    cidrs = {
      correct = { cidr = "10.0.0.0/8" }
    }
  }

  assert {
    condition     = aws_vpc_ipam_pool_cidr.this["correct"].cidr == "10.0.0.0/8"
    error_message = "Expected IPv4 CIDR to be accepted in IPv4 pool."
  }
}

run "test_accept_ipv6_cidr_in_ipv6_pool" {
  command = plan

  variables {
    name           = "test-pool"
    ipam_scope_id  = "ipam-scope-0123456789abcdef0"
    address_family = "ipv6"
    cidrs = {
      correct = { cidr = "2001:db8::/32" }
    }
  }

  assert {
    condition     = aws_vpc_ipam_pool_cidr.this["correct"].cidr == "2001:db8::/32"
    error_message = "Expected IPv6 CIDR to be accepted in IPv6 pool."
  }
}

################################################################################
# Multiple precondition failures at once
################################################################################

run "test_reject_multiple_ipv4_netmask_violations" {
  command = plan

  variables {
    name                              = "test-pool"
    ipam_scope_id                     = "ipam-scope-0123456789abcdef0"
    address_family                    = "ipv4"
    allocation_min_netmask_length     = 48
    allocation_max_netmask_length     = 64
    allocation_default_netmask_length = 56
  }

  # The IPv4 <= 32 precondition catches all three at once
  expect_failures = [aws_vpc_ipam_pool.this]
}
