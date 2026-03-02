################################################################################
# Precondition Unit Tests — AWS IPAM Module
#
# Tests lifecycle precondition blocks that enforce tier requirements for
# advanced-only features. These are runtime checks (not variable validations),
# so they use expect_failures on the resource rather than the variable.
################################################################################

mock_provider "aws" {}

################################################################################
# enable_private_gua requires tier = "advanced"
################################################################################

run "test_reject_private_gua_with_free_tier" {
  command = plan

  variables {
    name               = "test-ipam"
    operating_regions  = ["us-east-1"]
    tier               = "free"
    enable_private_gua = true
  }

  expect_failures = [aws_vpc_ipam.this]
}

run "test_accept_private_gua_with_advanced_tier" {
  command = plan

  variables {
    name               = "test-ipam"
    operating_regions  = ["us-east-1"]
    tier               = "advanced"
    enable_private_gua = true
  }

  assert {
    condition     = aws_vpc_ipam.this.enable_private_gua == true
    error_message = "Expected enable_private_gua to be accepted with advanced tier."
  }
}

################################################################################
# delegated_admin requires tier = "advanced"
################################################################################

run "test_reject_delegated_admin_with_free_tier" {
  command = plan

  variables {
    name                       = "test-ipam"
    operating_regions          = ["us-east-1"]
    tier                       = "free"
    delegated_admin_account_id = "123456789012"
  }

  expect_failures = [aws_vpc_ipam_organization_admin_account.this]
}

run "test_accept_delegated_admin_with_advanced_tier" {
  command = plan

  variables {
    name                       = "test-ipam"
    operating_regions          = ["us-east-1"]
    tier                       = "advanced"
    delegated_admin_account_id = "123456789012"
  }

  assert {
    condition     = length(aws_vpc_ipam_organization_admin_account.this) == 1
    error_message = "Expected delegated admin to be created with advanced tier."
  }
}

################################################################################
# resource_discovery requires tier = "advanced"
################################################################################

run "test_reject_resource_discovery_with_free_tier" {
  command = plan

  variables {
    name                       = "test-ipam"
    operating_regions          = ["us-east-1"]
    tier                       = "free"
    resource_discovery_enabled = true
  }

  expect_failures = [aws_vpc_ipam_resource_discovery.this]
}

run "test_accept_resource_discovery_with_advanced_tier" {
  command = plan

  variables {
    name                       = "test-ipam"
    operating_regions          = ["us-east-1"]
    tier                       = "advanced"
    resource_discovery_enabled = true
  }

  assert {
    condition     = length(aws_vpc_ipam_resource_discovery.this) == 1
    error_message = "Expected resource discovery to be created with advanced tier."
  }
}

################################################################################
# All advanced features enabled together with free tier should fail
################################################################################

run "test_reject_all_advanced_features_with_free_tier" {
  command = plan

  variables {
    name                       = "test-ipam"
    operating_regions          = ["us-east-1"]
    tier                       = "free"
    enable_private_gua         = true
    delegated_admin_account_id = "123456789012"
    resource_discovery_enabled = true
  }

  # Multiple resources have preconditions that fail with free tier:
  # - aws_vpc_ipam.this (enable_private_gua requires advanced)
  # - aws_vpc_ipam_organization_admin_account.this (delegated admin requires advanced)
  # - aws_vpc_ipam_resource_discovery.this (resource discovery requires advanced)
  expect_failures = [
    aws_vpc_ipam.this,
    aws_vpc_ipam_organization_admin_account.this,
    aws_vpc_ipam_resource_discovery.this,
  ]
}
