################################################################################
# Edge Cases Unit Tests — AWS IPAM Module
#
# Tests boundary conditions, minimum/maximum valid values, and unusual
# but valid input combinations.
#
# Note: Tests that create custom scopes are in custom_scopes_unit_test.tftest.hcl
# due to a module bug where custom_scope_types output references v.type instead
# of v.ipam_scope_type. See that file for details.
################################################################################

mock_provider "aws" {}

################################################################################
# Name Boundary Values
################################################################################

run "test_name_single_character" {
  command = plan

  variables {
    name              = "a"
    operating_regions = ["us-east-1"]
  }

  assert {
    condition     = aws_vpc_ipam.this.tags["Name"] == "a"
    error_message = "Expected single character name to be accepted."
  }
}

run "test_name_exactly_64_characters" {
  command = plan

  variables {
    name              = "a234567890123456789012345678901234567890123456789012345678901234"
    operating_regions = ["us-east-1"]
  }

  assert {
    condition     = aws_vpc_ipam.this.tags["Name"] == "a234567890123456789012345678901234567890123456789012345678901234"
    error_message = "Expected 64 character name to be accepted as the maximum length."
  }
}

run "test_name_all_hyphens" {
  command = plan

  variables {
    name              = "---"
    operating_regions = ["us-east-1"]
  }

  assert {
    condition     = aws_vpc_ipam.this.tags["Name"] == "---"
    error_message = "Expected name with only hyphens to be accepted (matches regex)."
  }
}

run "test_name_all_numbers" {
  command = plan

  variables {
    name              = "12345"
    operating_regions = ["us-east-1"]
  }

  assert {
    condition     = aws_vpc_ipam.this.tags["Name"] == "12345"
    error_message = "Expected name with only numbers to be accepted."
  }
}

run "test_name_mixed_case" {
  command = plan

  variables {
    name              = "My-IPAM-123"
    operating_regions = ["us-east-1"]
  }

  assert {
    condition     = aws_vpc_ipam.this.tags["Name"] == "My-IPAM-123"
    error_message = "Expected mixed-case name to be accepted."
  }
}

################################################################################
# Description Boundary Values
################################################################################

run "test_description_empty_string" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
    description       = ""
  }

  assert {
    condition     = aws_vpc_ipam.this.description == ""
    error_message = "Expected empty description to be accepted."
  }
}

run "test_description_exactly_256_characters" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
    description       = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }

  assert {
    condition     = aws_vpc_ipam.this.description == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    error_message = "Expected 256-character description to be accepted as the maximum length."
  }
}

################################################################################
# Operating Regions — Various valid formats
################################################################################

# Note: us-gov-west-1 FAILS the module's operating_regions regex. This is a
# module issue -- the regex ^[a-z]{2}(-[a-z]+-\d|gov-[a-z]+-\d)$ does not
# match GovCloud regions because "us-gov-west-1" requires matching "-gov-west-1"
# after the "us" prefix, but neither alternation handles that. Noted for reviewer.

run "test_operating_region_sa" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["sa-east-1"]
  }

  assert {
    condition     = length(aws_vpc_ipam.this.operating_regions) == 1
    error_message = "Expected sa-east-1 to be accepted as a valid operating region."
  }
}

run "test_operating_region_eu" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["eu-west-1"]
  }

  assert {
    condition     = length(aws_vpc_ipam.this.operating_regions) == 1
    error_message = "Expected eu-west-1 to be accepted as a valid operating region."
  }
}

run "test_operating_region_ap" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["ap-southeast-1"]
  }

  assert {
    condition     = length(aws_vpc_ipam.this.operating_regions) == 1
    error_message = "Expected ap-southeast-1 to be accepted as a valid operating region."
  }
}

run "test_operating_regions_many" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1", "us-west-2", "eu-west-1", "eu-central-1", "ap-southeast-1"]
  }

  assert {
    condition     = length(aws_vpc_ipam.this.operating_regions) == 5
    error_message = "Expected 5 operating regions to be accepted."
  }
}

################################################################################
# Delegated Admin Account ID — Boundary Values
################################################################################

run "test_delegated_admin_all_zeros" {
  command = plan

  variables {
    name                       = "test-ipam"
    operating_regions          = ["us-east-1"]
    tier                       = "advanced"
    delegated_admin_account_id = "000000000000"
  }

  assert {
    condition     = aws_vpc_ipam_organization_admin_account.this[0].delegated_admin_account_id == "000000000000"
    error_message = "Expected all-zero account ID to be accepted (valid format)."
  }
}

run "test_delegated_admin_all_nines" {
  command = plan

  variables {
    name                       = "test-ipam"
    operating_regions          = ["us-east-1"]
    tier                       = "advanced"
    delegated_admin_account_id = "999999999999"
  }

  assert {
    condition     = aws_vpc_ipam_organization_admin_account.this[0].delegated_admin_account_id == "999999999999"
    error_message = "Expected all-nines account ID to be accepted (valid format)."
  }
}

################################################################################
# Custom Scopes — Empty map edge case (no scopes created, so no v.type error)
################################################################################

run "test_custom_scopes_empty_map" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
    custom_scopes     = {}
  }

  assert {
    condition     = length(aws_vpc_ipam_scope.this) == 0
    error_message = "Expected no custom scopes when empty map is provided."
  }
}

################################################################################
# Tags — Edge Cases
################################################################################

run "test_empty_tags_map" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
    tags              = {}
  }

  assert {
    condition     = aws_vpc_ipam.this.tags["Name"] == "test-ipam"
    error_message = "Expected Name tag to still be set even with empty tags map."
  }
}

run "test_tags_with_many_entries" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
    tags = {
      Environment = "production"
      Team        = "platform"
      CostCenter  = "12345"
      Project     = "terraform-lab"
      ManagedBy   = "terraform"
    }
  }

  assert {
    condition     = aws_vpc_ipam.this.tags["Name"] == "test-ipam"
    error_message = "Expected Name tag to be preserved with many custom tags."
  }

  assert {
    condition     = aws_vpc_ipam.this.tags["CostCenter"] == "12345"
    error_message = "Expected CostCenter tag to be applied."
  }

  assert {
    condition     = aws_vpc_ipam.this.tags["ManagedBy"] == "terraform"
    error_message = "Expected ManagedBy tag to be applied."
  }
}

################################################################################
# Resource Discovery Description — Boundary Values
################################################################################

run "test_resource_discovery_description_empty" {
  command = plan

  variables {
    name                             = "test-ipam"
    operating_regions                = ["us-east-1"]
    tier                             = "advanced"
    resource_discovery_enabled       = true
    resource_discovery_description   = ""
  }

  assert {
    condition     = aws_vpc_ipam_resource_discovery.this[0].description == ""
    error_message = "Expected empty resource discovery description to be accepted."
  }
}

run "test_resource_discovery_description_exactly_256" {
  command = plan

  variables {
    name                             = "test-ipam"
    operating_regions                = ["us-east-1"]
    tier                             = "advanced"
    resource_discovery_enabled       = true
    resource_discovery_description   = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }

  assert {
    condition     = aws_vpc_ipam_resource_discovery.this[0].description == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    error_message = "Expected 256-character resource discovery description to be accepted."
  }
}

################################################################################
# Resource Discovery Operating Regions — Various valid formats
################################################################################

run "test_resource_discovery_region_different_from_ipam" {
  command = plan

  variables {
    name                                  = "test-ipam"
    operating_regions                     = ["us-east-1"]
    tier                                  = "advanced"
    resource_discovery_enabled            = true
    resource_discovery_operating_regions  = ["eu-central-1"]
  }

  assert {
    condition     = length(aws_vpc_ipam_resource_discovery.this[0].operating_regions) == 1
    error_message = "Expected resource discovery to accept a different region from IPAM operating regions."
  }
}

################################################################################
# Name Propagation to Sub-Resources (non-scope resources)
################################################################################

run "test_name_propagates_to_resource_discovery" {
  command = plan

  variables {
    name                       = "naming-test"
    operating_regions          = ["us-east-1"]
    tier                       = "advanced"
    resource_discovery_enabled = true
  }

  assert {
    condition     = aws_vpc_ipam.this.tags["Name"] == "naming-test"
    error_message = "Expected IPAM Name tag to match var.name."
  }

  assert {
    condition     = aws_vpc_ipam_resource_discovery.this[0].tags["Name"] == "naming-test-resource-discovery"
    error_message = "Expected resource discovery Name tag to be 'naming-test-resource-discovery'."
  }

  assert {
    condition     = aws_vpc_ipam_resource_discovery_association.this[0].tags["Name"] == "naming-test-discovery-association"
    error_message = "Expected discovery association Name tag to be 'naming-test-discovery-association'."
  }
}

################################################################################
# Custom Tags Propagate to Sub-Resources (non-scope resources)
################################################################################

run "test_custom_tags_on_resource_discovery" {
  command = plan

  variables {
    name                       = "tag-test"
    operating_regions          = ["us-east-1"]
    tier                       = "advanced"
    resource_discovery_enabled = true
    tags = {
      CostCenter = "12345"
    }
  }

  assert {
    condition     = aws_vpc_ipam_resource_discovery.this[0].tags["CostCenter"] == "12345"
    error_message = "Expected custom tags to propagate to resource discovery."
  }

  assert {
    condition     = aws_vpc_ipam_resource_discovery_association.this[0].tags["CostCenter"] == "12345"
    error_message = "Expected custom tags to propagate to resource discovery association."
  }
}
