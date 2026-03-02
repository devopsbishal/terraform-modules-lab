################################################################################
# Validation Unit Tests — AWS IPAM Pool Module
#
# Tests every validation block with invalid input using expect_failures.
# Each run block targets a specific validation rule and describes what
# invalid input it rejects.
################################################################################

mock_provider "aws" {}

# Required variables used across all tests (valid baseline)
# name              = "test-pool"
# ipam_scope_id     = "ipam-scope-0123456789abcdef0"

################################################################################
# address_family — Must be "ipv4" or "ipv6"
################################################################################

run "test_reject_address_family_invalid_value" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    address_family = "ipv8"
  }

  expect_failures = [var.address_family]
}

run "test_reject_address_family_empty_string" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    address_family = ""
  }

  expect_failures = [var.address_family]
}

run "test_reject_address_family_wrong_case" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    address_family = "IPv4"
  }

  expect_failures = [var.address_family]
}

################################################################################
# allocation_default_netmask_length — 0-128 range
################################################################################

run "test_reject_allocation_default_netmask_negative" {
  command = plan

  variables {
    name                               = "test-pool"
    ipam_scope_id                      = "ipam-scope-0123456789abcdef0"
    address_family                     = "ipv6"
    allocation_default_netmask_length  = -1
  }

  expect_failures = [var.allocation_default_netmask_length]
}

run "test_reject_allocation_default_netmask_too_large" {
  command = plan

  variables {
    name                               = "test-pool"
    ipam_scope_id                      = "ipam-scope-0123456789abcdef0"
    address_family                     = "ipv6"
    allocation_default_netmask_length  = 129
  }

  expect_failures = [var.allocation_default_netmask_length]
}

################################################################################
# allocation_max_netmask_length — 0-128 range
################################################################################

run "test_reject_allocation_max_netmask_negative" {
  command = plan

  variables {
    name                           = "test-pool"
    ipam_scope_id                  = "ipam-scope-0123456789abcdef0"
    address_family                 = "ipv6"
    allocation_max_netmask_length  = -1
  }

  expect_failures = [var.allocation_max_netmask_length]
}

run "test_reject_allocation_max_netmask_too_large" {
  command = plan

  variables {
    name                           = "test-pool"
    ipam_scope_id                  = "ipam-scope-0123456789abcdef0"
    address_family                 = "ipv6"
    allocation_max_netmask_length  = 129
  }

  expect_failures = [var.allocation_max_netmask_length]
}

################################################################################
# allocation_min_netmask_length — 0-128 range
################################################################################

run "test_reject_allocation_min_netmask_negative" {
  command = plan

  variables {
    name                           = "test-pool"
    ipam_scope_id                  = "ipam-scope-0123456789abcdef0"
    address_family                 = "ipv6"
    allocation_min_netmask_length  = -1
  }

  expect_failures = [var.allocation_min_netmask_length]
}

run "test_reject_allocation_min_netmask_too_large" {
  command = plan

  variables {
    name                           = "test-pool"
    ipam_scope_id                  = "ipam-scope-0123456789abcdef0"
    address_family                 = "ipv6"
    allocation_min_netmask_length  = 129
  }

  expect_failures = [var.allocation_min_netmask_length]
}

################################################################################
# aws_service — Must be "ec2" or null
################################################################################

run "test_reject_aws_service_invalid_value" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    aws_service   = "s3"
  }

  expect_failures = [var.aws_service]
}

run "test_reject_aws_service_empty_string" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    aws_service   = ""
  }

  expect_failures = [var.aws_service]
}

################################################################################
# cidrs — XOR validation (exactly one of cidr or netmask_length)
################################################################################

run "test_reject_cidrs_both_cidr_and_netmask" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    cidrs = {
      bad = {
        cidr           = "10.0.0.0/8"
        netmask_length = 16
      }
    }
  }

  expect_failures = [var.cidrs]
}

run "test_reject_cidrs_neither_cidr_nor_netmask" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    cidrs = {
      bad = {}
    }
  }

  expect_failures = [var.cidrs]
}

run "test_reject_cidrs_one_bad_entry_among_valid" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    cidrs = {
      good = {
        cidr = "10.0.0.0/8"
      }
      bad = {
        cidr           = "172.16.0.0/12"
        netmask_length = 16
      }
    }
  }

  expect_failures = [var.cidrs]
}

################################################################################
# cidrs — CIDR format validation
################################################################################

run "test_reject_cidrs_invalid_cidr_format" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    cidrs = {
      bad = {
        cidr = "not-a-cidr"
      }
    }
  }

  expect_failures = [var.cidrs]
}

run "test_reject_cidrs_cidr_missing_prefix" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    cidrs = {
      bad = {
        cidr = "10.0.0.0"
      }
    }
  }

  expect_failures = [var.cidrs]
}

################################################################################
# cidrs — netmask_length range validation (0-128)
################################################################################

run "test_reject_cidrs_netmask_length_negative" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    address_family = "ipv6"
    cidrs = {
      bad = {
        netmask_length = -1
      }
    }
  }

  expect_failures = [var.cidrs]
}

run "test_reject_cidrs_netmask_length_too_large" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    address_family = "ipv6"
    cidrs = {
      bad = {
        netmask_length = 129
      }
    }
  }

  expect_failures = [var.cidrs]
}

################################################################################
# description — Max 256 characters
################################################################################

run "test_reject_description_too_long" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    description   = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaX"
  }

  expect_failures = [var.description]
}

################################################################################
# ipam_scope_id — Format validation (ipam-scope-[0-9a-f]+)
################################################################################

run "test_reject_ipam_scope_id_invalid_format" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "not-a-scope-id"
  }

  expect_failures = [var.ipam_scope_id]
}

run "test_reject_ipam_scope_id_missing_prefix" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "0123456789abcdef0"
  }

  expect_failures = [var.ipam_scope_id]
}

run "test_reject_ipam_scope_id_wrong_prefix" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-pool-0123456789abcdef0"
  }

  expect_failures = [var.ipam_scope_id]
}

run "test_reject_ipam_scope_id_uppercase_hex" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789ABCDEF0"
  }

  expect_failures = [var.ipam_scope_id]
}

run "test_reject_ipam_scope_id_empty_string" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = ""
  }

  expect_failures = [var.ipam_scope_id]
}

################################################################################
# name — Non-empty, max 64 chars
################################################################################

run "test_reject_name_empty" {
  command = plan

  variables {
    name          = ""
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
  }

  expect_failures = [var.name]
}

run "test_reject_name_too_long_65_chars" {
  command = plan

  variables {
    name          = "a2345678901234567890123456789012345678901234567890123456789012345"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
  }

  expect_failures = [var.name]
}

################################################################################
# name — Alphanumeric + hyphens only
################################################################################

run "test_reject_name_with_underscores" {
  command = plan

  variables {
    name          = "my_pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
  }

  expect_failures = [var.name]
}

run "test_reject_name_with_spaces" {
  command = plan

  variables {
    name          = "my pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
  }

  expect_failures = [var.name]
}

run "test_reject_name_with_special_chars" {
  command = plan

  variables {
    name          = "my-pool@prod"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
  }

  expect_failures = [var.name]
}

run "test_reject_name_with_dots" {
  command = plan

  variables {
    name          = "my.pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
  }

  expect_failures = [var.name]
}

run "test_reject_name_with_slash" {
  command = plan

  variables {
    name          = "my/pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
  }

  expect_failures = [var.name]
}

################################################################################
# public_ip_source — Must be "byoip", "amazon", or null
################################################################################

run "test_reject_public_ip_source_invalid_value" {
  command = plan

  variables {
    name             = "test-pool"
    ipam_scope_id    = "ipam-scope-0123456789abcdef0"
    public_ip_source = "custom"
  }

  expect_failures = [var.public_ip_source]
}

run "test_reject_public_ip_source_empty_string" {
  command = plan

  variables {
    name             = "test-pool"
    ipam_scope_id    = "ipam-scope-0123456789abcdef0"
    public_ip_source = ""
  }

  expect_failures = [var.public_ip_source]
}

run "test_reject_public_ip_source_wrong_case" {
  command = plan

  variables {
    name             = "test-pool"
    ipam_scope_id    = "ipam-scope-0123456789abcdef0"
    public_ip_source = "Amazon"
  }

  expect_failures = [var.public_ip_source]
}

################################################################################
# source_ipam_pool_id — Format validation (ipam-pool-[0-9a-f]+)
################################################################################

run "test_reject_source_pool_id_invalid_format" {
  command = plan

  variables {
    name                = "test-pool"
    ipam_scope_id       = "ipam-scope-0123456789abcdef0"
    source_ipam_pool_id = "not-a-pool-id"
  }

  expect_failures = [var.source_ipam_pool_id]
}

run "test_reject_source_pool_id_wrong_prefix" {
  command = plan

  variables {
    name                = "test-pool"
    ipam_scope_id       = "ipam-scope-0123456789abcdef0"
    source_ipam_pool_id = "ipam-scope-0123456789abcdef0"
  }

  expect_failures = [var.source_ipam_pool_id]
}

run "test_reject_source_pool_id_uppercase_hex" {
  command = plan

  variables {
    name                = "test-pool"
    ipam_scope_id       = "ipam-scope-0123456789abcdef0"
    source_ipam_pool_id = "ipam-pool-0123456789ABCDEF0"
  }

  expect_failures = [var.source_ipam_pool_id]
}

run "test_reject_source_pool_id_empty_string" {
  command = plan

  variables {
    name                = "test-pool"
    ipam_scope_id       = "ipam-scope-0123456789abcdef0"
    source_ipam_pool_id = ""
  }

  expect_failures = [var.source_ipam_pool_id]
}

################################################################################
# locale — Valid AWS region format
################################################################################

run "test_reject_locale_invalid_format" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    locale        = "not-a-region"
  }

  expect_failures = [var.locale]
}

run "test_reject_locale_uppercase" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    locale        = "US-EAST-1"
  }

  expect_failures = [var.locale]
}

run "test_reject_locale_missing_number" {
  command = plan

  variables {
    name          = "test-pool"
    ipam_scope_id = "ipam-scope-0123456789abcdef0"
    locale        = "us-east"
  }

  expect_failures = [var.locale]
}
