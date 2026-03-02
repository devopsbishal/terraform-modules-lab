################################################################################
# Defaults Unit Tests — AWS IPAM Module
#
# Validates that the module produces a correct plan when only required
# variables (name, operating_regions) are provided and all defaults apply.
################################################################################

mock_provider "aws" {}

################################################################################
# IPAM Core Defaults
################################################################################

run "test_default_ipam_tier" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
  }

  assert {
    condition     = aws_vpc_ipam.this.tier == "free"
    error_message = "Expected IPAM tier to default to 'free', got '${aws_vpc_ipam.this.tier}'."
  }
}

run "test_default_cascade_delete" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
  }

  assert {
    condition     = aws_vpc_ipam.this.cascade == false
    error_message = "Expected IPAM cascade to default to false."
  }
}

run "test_default_enable_private_gua" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
  }

  assert {
    condition     = aws_vpc_ipam.this.enable_private_gua == false
    error_message = "Expected IPAM enable_private_gua to default to false."
  }
}

run "test_default_description_empty" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
  }

  assert {
    condition     = aws_vpc_ipam.this.description == ""
    error_message = "Expected IPAM description to default to empty string, got '${aws_vpc_ipam.this.description}'."
  }
}

run "test_default_operating_regions_single" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
  }

  assert {
    condition     = length(aws_vpc_ipam.this.operating_regions) == 1
    error_message = "Expected exactly 1 operating region, got ${length(aws_vpc_ipam.this.operating_regions)}."
  }
}

run "test_default_name_tag" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
  }

  assert {
    condition     = aws_vpc_ipam.this.tags["Name"] == "test-ipam"
    error_message = "Expected IPAM Name tag to be 'test-ipam', got '${aws_vpc_ipam.this.tags["Name"]}'."
  }
}

################################################################################
# Conditional Resources — Defaults should NOT create them
################################################################################

run "test_default_no_custom_scopes" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
  }

  assert {
    condition     = length(aws_vpc_ipam_scope.this) == 0
    error_message = "Expected no custom scopes to be created by default."
  }
}

run "test_default_no_delegated_admin" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
  }

  assert {
    condition     = length(aws_vpc_ipam_organization_admin_account.this) == 0
    error_message = "Expected no delegated admin to be created by default."
  }
}

run "test_default_no_resource_discovery" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
  }

  assert {
    condition     = length(aws_vpc_ipam_resource_discovery.this) == 0
    error_message = "Expected no resource discovery to be created by default."
  }
}

run "test_default_no_resource_discovery_association" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
  }

  assert {
    condition     = length(aws_vpc_ipam_resource_discovery_association.this) == 0
    error_message = "Expected no resource discovery association to be created by default."
  }
}

################################################################################
# Output Defaults
################################################################################

run "test_default_delegated_admin_output_null" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
  }

  assert {
    condition     = output.delegated_admin_account_arn == null
    error_message = "Expected delegated_admin_account_arn output to be null by default."
  }
}

run "test_default_resource_discovery_id_output_null" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
  }

  assert {
    condition     = output.resource_discovery_id == null
    error_message = "Expected resource_discovery_id output to be null by default."
  }
}

run "test_default_resource_discovery_arn_output_null" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
  }

  assert {
    condition     = output.resource_discovery_arn == null
    error_message = "Expected resource_discovery_arn output to be null by default."
  }
}

run "test_default_resource_discovery_association_output_null" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
  }

  assert {
    condition     = output.resource_discovery_association_id == null
    error_message = "Expected resource_discovery_association_id output to be null by default."
  }
}

run "test_default_custom_scope_ids_empty" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
  }

  assert {
    condition     = length(output.custom_scope_ids) == 0
    error_message = "Expected custom_scope_ids output to be empty by default."
  }
}

run "test_default_custom_scope_arns_empty" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
  }

  assert {
    condition     = length(output.custom_scope_arns) == 0
    error_message = "Expected custom_scope_arns output to be empty by default."
  }
}

run "test_default_custom_scope_types_empty" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
  }

  assert {
    condition     = length(output.custom_scope_types) == 0
    error_message = "Expected custom_scope_types output to be empty by default."
  }
}
