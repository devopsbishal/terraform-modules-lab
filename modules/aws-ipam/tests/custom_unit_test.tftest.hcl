################################################################################
# Custom Values Unit Tests — AWS IPAM Module
#
# Validates that the module correctly applies non-default variable values
# and that conditional resources are created or skipped based on flags.
#
# Note: Custom scope tests are in custom_scopes_unit_test.tftest.hcl because
# the custom_scope_types output references v.type (should be v.ipam_scope_type),
# which causes a plan error when scopes are created. That module bug is noted
# for the reviewer. Tests here do NOT create custom scopes.
################################################################################

mock_provider "aws" {}

################################################################################
# Custom IPAM Settings
################################################################################

run "test_custom_tier_advanced" {
  command = plan

  variables {
    name              = "custom-ipam"
    operating_regions = ["us-east-1"]
    tier              = "advanced"
  }

  assert {
    condition     = aws_vpc_ipam.this.tier == "advanced"
    error_message = "Expected IPAM tier to be 'advanced', got '${aws_vpc_ipam.this.tier}'."
  }
}

run "test_custom_cascade_delete_enabled" {
  command = plan

  variables {
    name              = "custom-ipam"
    operating_regions = ["us-east-1"]
    cascade_delete    = true
  }

  assert {
    condition     = aws_vpc_ipam.this.cascade == true
    error_message = "Expected IPAM cascade to be true when cascade_delete is enabled."
  }
}

run "test_custom_description" {
  command = plan

  variables {
    name              = "custom-ipam"
    operating_regions = ["us-east-1"]
    description       = "Production IPAM for centralized IP management"
  }

  assert {
    condition     = aws_vpc_ipam.this.description == "Production IPAM for centralized IP management"
    error_message = "Expected IPAM description to match provided value."
  }
}

run "test_custom_enable_private_gua" {
  command = plan

  variables {
    name               = "custom-ipam"
    operating_regions  = ["us-east-1"]
    tier               = "advanced"
    enable_private_gua = true
  }

  assert {
    condition     = aws_vpc_ipam.this.enable_private_gua == true
    error_message = "Expected IPAM enable_private_gua to be true when explicitly set."
  }
}

run "test_custom_multiple_operating_regions" {
  command = plan

  variables {
    name              = "multi-region-ipam"
    operating_regions = ["us-east-1", "us-west-2", "eu-west-1"]
  }

  assert {
    condition     = length(aws_vpc_ipam.this.operating_regions) == 3
    error_message = "Expected 3 operating regions, got ${length(aws_vpc_ipam.this.operating_regions)}."
  }
}

run "test_custom_tags_merged" {
  command = plan

  variables {
    name              = "custom-ipam"
    operating_regions = ["us-east-1"]
    tags = {
      Environment = "staging"
      Team        = "platform"
    }
  }

  assert {
    condition     = aws_vpc_ipam.this.tags["Name"] == "custom-ipam"
    error_message = "Expected Name tag to be preserved when custom tags are provided."
  }

  assert {
    condition     = aws_vpc_ipam.this.tags["Environment"] == "staging"
    error_message = "Expected custom Environment tag to be applied."
  }

  assert {
    condition     = aws_vpc_ipam.this.tags["Team"] == "platform"
    error_message = "Expected custom Team tag to be applied."
  }
}

################################################################################
# Delegated Admin Account
################################################################################

run "test_custom_delegated_admin_created" {
  command = plan

  variables {
    name                        = "org-ipam"
    operating_regions           = ["us-east-1"]
    tier                        = "advanced"
    delegated_admin_account_id  = "123456789012"
  }

  assert {
    condition     = length(aws_vpc_ipam_organization_admin_account.this) == 1
    error_message = "Expected delegated admin to be created when account ID is provided."
  }

  assert {
    condition     = aws_vpc_ipam_organization_admin_account.this[0].delegated_admin_account_id == "123456789012"
    error_message = "Expected delegated admin account ID to be '123456789012'."
  }
}

run "test_custom_delegated_admin_not_created_when_null" {
  command = plan

  variables {
    name                        = "org-ipam"
    operating_regions           = ["us-east-1"]
    tier                        = "advanced"
    delegated_admin_account_id  = null
  }

  assert {
    condition     = length(aws_vpc_ipam_organization_admin_account.this) == 0
    error_message = "Expected no delegated admin when account ID is null."
  }
}

################################################################################
# Resource Discovery
################################################################################

run "test_custom_resource_discovery_enabled" {
  command = plan

  variables {
    name                       = "discovery-ipam"
    operating_regions          = ["us-east-1"]
    tier                       = "advanced"
    resource_discovery_enabled = true
  }

  assert {
    condition     = length(aws_vpc_ipam_resource_discovery.this) == 1
    error_message = "Expected resource discovery to be created when enabled."
  }
}

run "test_custom_resource_discovery_association_created" {
  command = plan

  variables {
    name                       = "discovery-ipam"
    operating_regions          = ["us-east-1"]
    tier                       = "advanced"
    resource_discovery_enabled = true
  }

  assert {
    condition     = length(aws_vpc_ipam_resource_discovery_association.this) == 1
    error_message = "Expected resource discovery association to be created alongside discovery."
  }
}

run "test_custom_resource_discovery_description" {
  command = plan

  variables {
    name                             = "discovery-ipam"
    operating_regions                = ["us-east-1"]
    tier                             = "advanced"
    resource_discovery_enabled       = true
    resource_discovery_description   = "Cross-org IP monitoring"
  }

  assert {
    condition     = aws_vpc_ipam_resource_discovery.this[0].description == "Cross-org IP monitoring"
    error_message = "Expected resource discovery description to match provided value."
  }
}

run "test_custom_resource_discovery_name_tag" {
  command = plan

  variables {
    name                       = "discovery-ipam"
    operating_regions          = ["us-east-1"]
    tier                       = "advanced"
    resource_discovery_enabled = true
  }

  assert {
    condition     = aws_vpc_ipam_resource_discovery.this[0].tags["Name"] == "discovery-ipam-resource-discovery"
    error_message = "Expected resource discovery Name tag to be 'discovery-ipam-resource-discovery'."
  }
}

run "test_custom_resource_discovery_association_name_tag" {
  command = plan

  variables {
    name                       = "discovery-ipam"
    operating_regions          = ["us-east-1"]
    tier                       = "advanced"
    resource_discovery_enabled = true
  }

  assert {
    condition     = aws_vpc_ipam_resource_discovery_association.this[0].tags["Name"] == "discovery-ipam-discovery-association"
    error_message = "Expected discovery association Name tag to be 'discovery-ipam-discovery-association'."
  }
}

run "test_custom_resource_discovery_falls_back_to_ipam_regions" {
  command = plan

  variables {
    name                       = "discovery-ipam"
    operating_regions          = ["us-east-1", "us-west-2"]
    tier                       = "advanced"
    resource_discovery_enabled = true
  }

  # When resource_discovery_operating_regions is empty (default), it falls back
  # to the IPAM operating_regions
  assert {
    condition     = length(aws_vpc_ipam_resource_discovery.this[0].operating_regions) == 2
    error_message = "Expected resource discovery to use IPAM operating regions as fallback."
  }
}

run "test_custom_resource_discovery_explicit_regions" {
  command = plan

  variables {
    name                                  = "discovery-ipam"
    operating_regions                     = ["us-east-1", "us-west-2"]
    tier                                  = "advanced"
    resource_discovery_enabled            = true
    resource_discovery_operating_regions  = ["eu-west-1"]
  }

  assert {
    condition     = length(aws_vpc_ipam_resource_discovery.this[0].operating_regions) == 1
    error_message = "Expected resource discovery to use its own operating regions when explicitly set."
  }
}

run "test_custom_resource_discovery_disabled" {
  command = plan

  variables {
    name                       = "no-discovery-ipam"
    operating_regions          = ["us-east-1"]
    tier                       = "advanced"
    resource_discovery_enabled = false
  }

  assert {
    condition     = length(aws_vpc_ipam_resource_discovery.this) == 0
    error_message = "Expected no resource discovery when disabled."
  }

  assert {
    condition     = length(aws_vpc_ipam_resource_discovery_association.this) == 0
    error_message = "Expected no resource discovery association when discovery is disabled."
  }
}
