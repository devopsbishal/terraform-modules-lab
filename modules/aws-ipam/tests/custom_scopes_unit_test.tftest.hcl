################################################################################
# Custom Scopes Unit Tests — AWS IPAM Module
#
# Tests for custom IPAM scope creation via the custom_scopes variable.
#
# KNOWN MODULE BUG: The custom_scope_types output in outputs.tf references
# `v.type` but the actual aws_vpc_ipam_scope attribute is `ipam_scope_type`.
# All tests that create custom scopes will fail until the module is fixed.
# This file is separated from custom_unit_test.tftest.hcl so the bug does
# not block other tests from running.
#
# Fix needed in outputs.tf line 13:
#   value = { for k, v in aws_vpc_ipam_scope.this : k => v.ipam_scope_type }
################################################################################

mock_provider "aws" {}

################################################################################
# Custom Scope Creation
################################################################################

run "test_custom_single_scope" {
  command = plan

  variables {
    name              = "custom-ipam"
    operating_regions = ["us-east-1"]
    custom_scopes = {
      production = "Scope for production workloads"
    }
  }

  assert {
    condition     = length(aws_vpc_ipam_scope.this) == 1
    error_message = "Expected 1 custom scope, got ${length(aws_vpc_ipam_scope.this)}."
  }

  assert {
    condition     = aws_vpc_ipam_scope.this["production"].description == "Scope for production workloads"
    error_message = "Expected custom scope description to match provided value."
  }

  assert {
    condition     = aws_vpc_ipam_scope.this["production"].tags["Name"] == "custom-ipam-production"
    error_message = "Expected custom scope Name tag to be 'custom-ipam-production', got '${aws_vpc_ipam_scope.this["production"].tags["Name"]}'."
  }
}

run "test_custom_multiple_scopes" {
  command = plan

  variables {
    name              = "custom-ipam"
    operating_regions = ["us-east-1"]
    custom_scopes = {
      production  = "Scope for production workloads"
      development = "Scope for dev/test workloads"
      shared      = "Scope for shared services"
    }
  }

  assert {
    condition     = length(aws_vpc_ipam_scope.this) == 3
    error_message = "Expected 3 custom scopes, got ${length(aws_vpc_ipam_scope.this)}."
  }

  assert {
    condition     = aws_vpc_ipam_scope.this["development"].description == "Scope for dev/test workloads"
    error_message = "Expected development scope description to match."
  }
}

run "test_custom_scope_inherits_base_tags" {
  command = plan

  variables {
    name              = "custom-ipam"
    operating_regions = ["us-east-1"]
    custom_scopes = {
      production = "Scope for production"
    }
    tags = {
      Environment = "production"
    }
  }

  assert {
    condition     = aws_vpc_ipam_scope.this["production"].tags["Environment"] == "production"
    error_message = "Expected custom scope to inherit base tags."
  }

  assert {
    condition     = aws_vpc_ipam_scope.this["production"].tags["Name"] == "custom-ipam-production"
    error_message = "Expected custom scope Name tag to include scope key."
  }
}

################################################################################
# Scope Edge Cases
################################################################################

run "test_custom_scope_long_description" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
    custom_scopes = {
      production = "This is a longer description for the production scope that explains its purpose in detail for team members who need to understand the scope boundaries"
    }
  }

  assert {
    condition     = length(aws_vpc_ipam_scope.this) == 1
    error_message = "Expected scope with long description to be accepted."
  }
}

################################################################################
# Name Propagation to Custom Scopes
################################################################################

run "test_name_propagates_to_custom_scopes" {
  command = plan

  variables {
    name              = "naming-test"
    operating_regions = ["us-east-1"]
    custom_scopes = {
      alpha = "First scope"
      beta  = "Second scope"
    }
  }

  assert {
    condition     = aws_vpc_ipam_scope.this["alpha"].tags["Name"] == "naming-test-alpha"
    error_message = "Expected alpha scope Name tag to be 'naming-test-alpha'."
  }

  assert {
    condition     = aws_vpc_ipam_scope.this["beta"].tags["Name"] == "naming-test-beta"
    error_message = "Expected beta scope Name tag to be 'naming-test-beta'."
  }
}

################################################################################
# Custom Tags Propagate to Custom Scopes
################################################################################

run "test_custom_tags_on_custom_scopes" {
  command = plan

  variables {
    name              = "tag-test"
    operating_regions = ["us-east-1"]
    custom_scopes = {
      production = "Prod scope"
    }
    tags = {
      Environment = "production"
    }
  }

  assert {
    condition     = aws_vpc_ipam_scope.this["production"].tags["Environment"] == "production"
    error_message = "Expected custom tags to propagate to custom scopes."
  }
}

################################################################################
# Full Advanced Configuration (with scopes)
################################################################################

run "test_custom_all_advanced_features" {
  command = plan

  variables {
    name                                  = "full-ipam"
    operating_regions                     = ["us-east-1", "us-west-2"]
    tier                                  = "advanced"
    cascade_delete                        = true
    enable_private_gua                    = true
    description                           = "Full-featured IPAM"
    delegated_admin_account_id            = "987654321098"
    resource_discovery_enabled            = true
    resource_discovery_description        = "Multi-account discovery"
    resource_discovery_operating_regions  = ["us-east-1", "eu-west-1"]
    custom_scopes = {
      production  = "Production scope"
      development = "Development scope"
    }
    tags = {
      Environment = "production"
      ManagedBy   = "terraform"
    }
  }

  assert {
    condition     = aws_vpc_ipam.this.tier == "advanced"
    error_message = "Expected tier to be 'advanced'."
  }

  assert {
    condition     = aws_vpc_ipam.this.cascade == true
    error_message = "Expected cascade to be true."
  }

  assert {
    condition     = aws_vpc_ipam.this.enable_private_gua == true
    error_message = "Expected enable_private_gua to be true."
  }

  assert {
    condition     = length(aws_vpc_ipam_scope.this) == 2
    error_message = "Expected 2 custom scopes."
  }

  assert {
    condition     = length(aws_vpc_ipam_organization_admin_account.this) == 1
    error_message = "Expected delegated admin to be created."
  }

  assert {
    condition     = length(aws_vpc_ipam_resource_discovery.this) == 1
    error_message = "Expected resource discovery to be created."
  }

  assert {
    condition     = length(aws_vpc_ipam_resource_discovery_association.this) == 1
    error_message = "Expected resource discovery association to be created."
  }
}
