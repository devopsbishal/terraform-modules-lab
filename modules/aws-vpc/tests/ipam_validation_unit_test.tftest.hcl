################################################################################
# IPAM Validation Unit Tests — AWS VPC Module
#
# Tests every IPAM-related validation block with invalid input using
# expect_failures. Covers ipv4_netmask_length range, ipv6_netmask_length
# allowed values, and all VPC preconditions for IPAM mutual exclusivity.
################################################################################

mock_provider "aws" {}

################################################################################
# ipv4_netmask_length — Must be between 16 and 28 (or null)
################################################################################

run "test_reject_ipv4_netmask_length_below_16" {
  command = plan

  variables {
    name                 = "test-vpc"
    ipv4_ipam_pool_id    = "ipam-pool-0123456789abcdef0"
    ipv4_netmask_length  = 15
    flow_log_enabled     = false
  }

  expect_failures = [var.ipv4_netmask_length]
}

run "test_reject_ipv4_netmask_length_8" {
  command = plan

  variables {
    name                 = "test-vpc"
    ipv4_ipam_pool_id    = "ipam-pool-0123456789abcdef0"
    ipv4_netmask_length  = 8
    flow_log_enabled     = false
  }

  expect_failures = [var.ipv4_netmask_length]
}

run "test_reject_ipv4_netmask_length_above_28" {
  command = plan

  variables {
    name                 = "test-vpc"
    ipv4_ipam_pool_id    = "ipam-pool-0123456789abcdef0"
    ipv4_netmask_length  = 29
    flow_log_enabled     = false
  }

  expect_failures = [var.ipv4_netmask_length]
}

run "test_reject_ipv4_netmask_length_32" {
  command = plan

  variables {
    name                 = "test-vpc"
    ipv4_ipam_pool_id    = "ipam-pool-0123456789abcdef0"
    ipv4_netmask_length  = 32
    flow_log_enabled     = false
  }

  expect_failures = [var.ipv4_netmask_length]
}

run "test_reject_ipv4_netmask_length_0" {
  command = plan

  variables {
    name                 = "test-vpc"
    ipv4_ipam_pool_id    = "ipam-pool-0123456789abcdef0"
    ipv4_netmask_length  = 0
    flow_log_enabled     = false
  }

  expect_failures = [var.ipv4_netmask_length]
}

################################################################################
# ipv6_netmask_length — Must be one of: 44, 48, 52, 56, 60 (or null)
################################################################################

run "test_reject_ipv6_netmask_length_45" {
  command = plan

  variables {
    name                = "test-vpc"
    cidr_block          = "10.0.0.0/16"
    ipv6_ipam_pool_id   = "ipam-pool-0123456789abcdef1"
    ipv6_netmask_length = 45
    flow_log_enabled    = false
  }

  expect_failures = [var.ipv6_netmask_length]
}

run "test_reject_ipv6_netmask_length_50" {
  command = plan

  variables {
    name                = "test-vpc"
    cidr_block          = "10.0.0.0/16"
    ipv6_ipam_pool_id   = "ipam-pool-0123456789abcdef1"
    ipv6_netmask_length = 50
    flow_log_enabled    = false
  }

  expect_failures = [var.ipv6_netmask_length]
}

run "test_reject_ipv6_netmask_length_46" {
  command = plan

  variables {
    name                = "test-vpc"
    cidr_block          = "10.0.0.0/16"
    ipv6_ipam_pool_id   = "ipam-pool-0123456789abcdef1"
    ipv6_netmask_length = 46
    flow_log_enabled    = false
  }

  expect_failures = [var.ipv6_netmask_length]
}

run "test_reject_ipv6_netmask_length_64" {
  command = plan

  variables {
    name                = "test-vpc"
    cidr_block          = "10.0.0.0/16"
    ipv6_ipam_pool_id   = "ipam-pool-0123456789abcdef1"
    ipv6_netmask_length = 64
    flow_log_enabled    = false
  }

  expect_failures = [var.ipv6_netmask_length]
}

run "test_reject_ipv6_netmask_length_40" {
  command = plan

  variables {
    name                = "test-vpc"
    cidr_block          = "10.0.0.0/16"
    ipv6_ipam_pool_id   = "ipam-pool-0123456789abcdef1"
    ipv6_netmask_length = 40
    flow_log_enabled    = false
  }

  expect_failures = [var.ipv6_netmask_length]
}

run "test_reject_ipv6_netmask_length_0" {
  command = plan

  variables {
    name                = "test-vpc"
    cidr_block          = "10.0.0.0/16"
    ipv6_ipam_pool_id   = "ipam-pool-0123456789abcdef1"
    ipv6_netmask_length = 0
    flow_log_enabled    = false
  }

  expect_failures = [var.ipv6_netmask_length]
}

run "test_reject_ipv6_netmask_length_128" {
  command = plan

  variables {
    name                = "test-vpc"
    cidr_block          = "10.0.0.0/16"
    ipv6_ipam_pool_id   = "ipam-pool-0123456789abcdef1"
    ipv6_netmask_length = 128
    flow_log_enabled    = false
  }

  expect_failures = [var.ipv6_netmask_length]
}

################################################################################
# Precondition: cidr_block and ipv4_ipam_pool_id are mutually exclusive
################################################################################

run "test_reject_both_cidr_and_ipv4_ipam_pool" {
  command = plan

  variables {
    name                = "test-vpc"
    cidr_block          = "10.0.0.0/16"
    ipv4_ipam_pool_id   = "ipam-pool-0123456789abcdef0"
    ipv4_netmask_length = 16
    flow_log_enabled    = false
  }

  expect_failures = [aws_vpc.this]
}

################################################################################
# Precondition: One of cidr_block or ipv4_ipam_pool_id must be provided
################################################################################

run "test_reject_neither_cidr_nor_ipv4_ipam_pool" {
  command = plan

  variables {
    name             = "test-vpc"
    flow_log_enabled = false
  }

  expect_failures = [aws_vpc.this]
}

################################################################################
# Precondition: ipv4_netmask_length requires ipv4_ipam_pool_id
################################################################################

run "test_reject_ipv4_netmask_without_ipam_pool" {
  command = plan

  variables {
    name                = "test-vpc"
    cidr_block          = "10.0.0.0/16"
    ipv4_netmask_length = 20
    flow_log_enabled    = false
  }

  expect_failures = [aws_vpc.this]
}

################################################################################
# Precondition: ipv4_ipam_pool_id requires ipv4_netmask_length
################################################################################

run "test_reject_ipv4_ipam_pool_without_netmask" {
  command = plan

  variables {
    name              = "test-vpc"
    ipv4_ipam_pool_id = "ipam-pool-0123456789abcdef0"
    flow_log_enabled  = false
  }

  expect_failures = [aws_vpc.this]
}

################################################################################
# Precondition: ipv6_netmask_length requires ipv6_ipam_pool_id
################################################################################

run "test_reject_ipv6_netmask_without_ipam_pool" {
  command = plan

  variables {
    name                = "test-vpc"
    cidr_block          = "10.0.0.0/16"
    ipv6_netmask_length = 56
    flow_log_enabled    = false
  }

  expect_failures = [aws_vpc.this]
}

################################################################################
# Precondition: ipv6_ipam_pool_id requires ipv6_netmask_length
################################################################################

run "test_reject_ipv6_ipam_pool_without_netmask" {
  command = plan

  variables {
    name              = "test-vpc"
    cidr_block        = "10.0.0.0/16"
    ipv6_ipam_pool_id = "ipam-pool-0123456789abcdef1"
    flow_log_enabled  = false
  }

  expect_failures = [aws_vpc.this]
}

################################################################################
# Precondition: assign_generated_ipv6_cidr_block and ipv6_ipam_pool_id
# are mutually exclusive
################################################################################

run "test_reject_ipv6_generated_and_ipam_both_set" {
  command = plan

  variables {
    name                             = "test-vpc"
    cidr_block                       = "10.0.0.0/16"
    assign_generated_ipv6_cidr_block = true
    ipv6_ipam_pool_id                = "ipam-pool-0123456789abcdef1"
    ipv6_netmask_length              = 56
    flow_log_enabled                 = false
  }

  expect_failures = [aws_vpc.this]
}
