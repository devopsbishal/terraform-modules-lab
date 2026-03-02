################################################################################
# Validation Unit Tests — AWS IPAM Module
#
# Tests every validation block with invalid input using expect_failures.
# Each run block targets a specific validation rule and describes what
# invalid input it rejects.
################################################################################

mock_provider "aws" {}

################################################################################
# name — Length Validation (1 to 64 characters)
################################################################################

run "test_reject_name_empty" {
  command = plan

  variables {
    name              = ""
    operating_regions = ["us-east-1"]
  }

  expect_failures = [var.name]
}

run "test_reject_name_too_long_65_chars" {
  command = plan

  variables {
    name              = "a2345678901234567890123456789012345678901234567890123456789012345"
    operating_regions = ["us-east-1"]
  }

  expect_failures = [var.name]
}

################################################################################
# name — Character Pattern (alphanumeric + hyphens only)
################################################################################

run "test_reject_name_with_underscores" {
  command = plan

  variables {
    name              = "my_ipam"
    operating_regions = ["us-east-1"]
  }

  expect_failures = [var.name]
}

run "test_reject_name_with_spaces" {
  command = plan

  variables {
    name              = "my ipam"
    operating_regions = ["us-east-1"]
  }

  expect_failures = [var.name]
}

run "test_reject_name_with_special_chars" {
  command = plan

  variables {
    name              = "my-ipam@prod"
    operating_regions = ["us-east-1"]
  }

  expect_failures = [var.name]
}

run "test_reject_name_with_dots" {
  command = plan

  variables {
    name              = "my.ipam"
    operating_regions = ["us-east-1"]
  }

  expect_failures = [var.name]
}

run "test_reject_name_with_slash" {
  command = plan

  variables {
    name              = "my/ipam"
    operating_regions = ["us-east-1"]
  }

  expect_failures = [var.name]
}

################################################################################
# tier — Must be "free" or "advanced"
################################################################################

run "test_reject_tier_invalid_value" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
    tier              = "premium"
  }

  expect_failures = [var.tier]
}

run "test_reject_tier_empty_string" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
    tier              = ""
  }

  expect_failures = [var.tier]
}

run "test_reject_tier_wrong_case" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
    tier              = "Free"
  }

  expect_failures = [var.tier]
}

run "test_reject_tier_advanced_wrong_case" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
    tier              = "Advanced"
  }

  expect_failures = [var.tier]
}

################################################################################
# description — Max length 256 characters
################################################################################

run "test_reject_description_too_long" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
    description       = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaX"
  }

  expect_failures = [var.description]
}

################################################################################
# operating_regions — At least one region required
################################################################################

run "test_reject_operating_regions_empty" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = []
  }

  expect_failures = [var.operating_regions]
}

################################################################################
# operating_regions — Valid AWS region format
################################################################################

run "test_reject_operating_regions_invalid_format" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["not-a-region"]
  }

  expect_failures = [var.operating_regions]
}

run "test_reject_operating_regions_uppercase" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["US-EAST-1"]
  }

  expect_failures = [var.operating_regions]
}

run "test_reject_operating_regions_missing_number" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east"]
  }

  expect_failures = [var.operating_regions]
}

run "test_reject_operating_regions_one_invalid_among_valid" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1", "invalid-region", "eu-west-1"]
  }

  expect_failures = [var.operating_regions]
}

################################################################################
# delegated_admin_account_id — 12-digit AWS account ID format
################################################################################

run "test_reject_delegated_admin_too_short" {
  command = plan

  variables {
    name                       = "test-ipam"
    operating_regions          = ["us-east-1"]
    tier                       = "advanced"
    delegated_admin_account_id = "12345"
  }

  expect_failures = [var.delegated_admin_account_id]
}

run "test_reject_delegated_admin_too_long" {
  command = plan

  variables {
    name                       = "test-ipam"
    operating_regions          = ["us-east-1"]
    tier                       = "advanced"
    delegated_admin_account_id = "1234567890123"
  }

  expect_failures = [var.delegated_admin_account_id]
}

run "test_reject_delegated_admin_non_numeric" {
  command = plan

  variables {
    name                       = "test-ipam"
    operating_regions          = ["us-east-1"]
    tier                       = "advanced"
    delegated_admin_account_id = "12345678901a"
  }

  expect_failures = [var.delegated_admin_account_id]
}

run "test_reject_delegated_admin_empty_string" {
  command = plan

  variables {
    name                       = "test-ipam"
    operating_regions          = ["us-east-1"]
    tier                       = "advanced"
    delegated_admin_account_id = ""
  }

  expect_failures = [var.delegated_admin_account_id]
}

################################################################################
# custom_scopes — Non-empty description required
################################################################################

run "test_reject_custom_scope_empty_description" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
    custom_scopes = {
      production = ""
    }
  }

  expect_failures = [var.custom_scopes]
}

run "test_reject_custom_scope_whitespace_only_description" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
    custom_scopes = {
      production = "   "
    }
  }

  expect_failures = [var.custom_scopes]
}

run "test_reject_custom_scope_one_empty_among_valid" {
  command = plan

  variables {
    name              = "test-ipam"
    operating_regions = ["us-east-1"]
    custom_scopes = {
      production  = "Production scope"
      development = ""
    }
  }

  expect_failures = [var.custom_scopes]
}

################################################################################
# resource_discovery_description — Max length 256 characters
################################################################################

run "test_reject_resource_discovery_description_too_long" {
  command = plan

  variables {
    name                             = "test-ipam"
    operating_regions                = ["us-east-1"]
    tier                             = "advanced"
    resource_discovery_enabled       = true
    resource_discovery_description   = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaX"
  }

  expect_failures = [var.resource_discovery_description]
}

################################################################################
# resource_discovery_operating_regions — Valid AWS region format
################################################################################

run "test_reject_resource_discovery_regions_invalid" {
  command = plan

  variables {
    name                                  = "test-ipam"
    operating_regions                     = ["us-east-1"]
    tier                                  = "advanced"
    resource_discovery_enabled            = true
    resource_discovery_operating_regions  = ["not-valid"]
  }

  expect_failures = [var.resource_discovery_operating_regions]
}

run "test_reject_resource_discovery_regions_mixed_valid_invalid" {
  command = plan

  variables {
    name                                  = "test-ipam"
    operating_regions                     = ["us-east-1"]
    tier                                  = "advanced"
    resource_discovery_enabled            = true
    resource_discovery_operating_regions  = ["us-east-1", "bad-region"]
  }

  expect_failures = [var.resource_discovery_operating_regions]
}
