################################################################################
# Validation Unit Tests — AWS VPC Module
#
# Tests every validation block with invalid input using expect_failures.
# Each run block targets a specific validation rule and describes what
# invalid input it rejects.
################################################################################

mock_provider "aws" {
  override_data {
    target = data.aws_caller_identity.current[0]
    values = {
      account_id = "123456789012"
    }
  }

  override_data {
    target = data.aws_iam_policy_document.flow_log_assume_role[0]
    values = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"vpc-flow-logs.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    }
  }

  override_data {
    target = data.aws_iam_policy_document.flow_log_permissions[0]
    values = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"logs:CreateLogStream\",\"logs:PutLogEvents\"],\"Resource\":\"*\"}]}"
    }
  }
}

################################################################################
# cidr_block — Invalid CIDR Format
################################################################################

run "test_reject_cidr_invalid_octets" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "999.999.999.999/16"
  }

  expect_failures = [var.cidr_block]
}

run "test_reject_cidr_not_ip_format" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "hello/16"
  }

  expect_failures = [var.cidr_block]
}

################################################################################
# cidr_block — Prefix Length Out of Range (/16 to /24)
################################################################################

run "test_reject_cidr_prefix_shorter_than_16" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/8"
  }

  expect_failures = [var.cidr_block]
}

run "test_reject_cidr_prefix_15" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/15"
  }

  expect_failures = [var.cidr_block]
}

run "test_reject_cidr_prefix_25" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/25"
  }

  expect_failures = [var.cidr_block]
}

run "test_reject_cidr_prefix_28" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/28"
  }

  expect_failures = [var.cidr_block]
}

run "test_reject_cidr_prefix_32" {
  command = plan

  variables {
    name       = "test-vpc"
    cidr_block = "10.0.0.0/32"
  }

  expect_failures = [var.cidr_block]
}

################################################################################
# name — Length Validation (1 to 64 characters)
################################################################################

run "test_reject_name_empty" {
  command = plan

  variables {
    name       = ""
    cidr_block = "10.0.0.0/16"
  }

  expect_failures = [var.name]
}

run "test_reject_name_too_long" {
  command = plan

  variables {
    name       = "a234567890123456789012345678901234567890123456X"
    cidr_block = "10.0.0.0/16"
  }

  expect_failures = [var.name]
}

################################################################################
# name — Character Pattern (alphanumeric + hyphens only)
################################################################################

run "test_reject_name_with_underscores" {
  command = plan

  variables {
    name       = "my_vpc"
    cidr_block = "10.0.0.0/16"
  }

  expect_failures = [var.name]
}

run "test_reject_name_with_spaces" {
  command = plan

  variables {
    name       = "my vpc"
    cidr_block = "10.0.0.0/16"
  }

  expect_failures = [var.name]
}

run "test_reject_name_with_special_chars" {
  command = plan

  variables {
    name       = "my-vpc@prod"
    cidr_block = "10.0.0.0/16"
  }

  expect_failures = [var.name]
}

run "test_reject_name_with_dots" {
  command = plan

  variables {
    name       = "my.vpc"
    cidr_block = "10.0.0.0/16"
  }

  expect_failures = [var.name]
}

################################################################################
# flow_log_destination_type — Must be "cloud-watch-logs" or "s3"
################################################################################

run "test_reject_invalid_flow_log_destination_type" {
  command = plan

  variables {
    name                      = "test-vpc"
    cidr_block                = "10.0.0.0/16"
    flow_log_destination_type = "kinesis"
  }

  expect_failures = [var.flow_log_destination_type]
}

run "test_reject_empty_flow_log_destination_type" {
  command = plan

  variables {
    name                      = "test-vpc"
    cidr_block                = "10.0.0.0/16"
    flow_log_destination_type = ""
  }

  expect_failures = [var.flow_log_destination_type]
}

run "test_reject_flow_log_destination_type_wrong_case" {
  command = plan

  variables {
    name                      = "test-vpc"
    cidr_block                = "10.0.0.0/16"
    flow_log_destination_type = "S3"
  }

  expect_failures = [var.flow_log_destination_type]
}

################################################################################
# flow_log_traffic_type — Must be "ACCEPT", "REJECT", or "ALL"
################################################################################

run "test_reject_invalid_flow_log_traffic_type" {
  command = plan

  variables {
    name                  = "test-vpc"
    cidr_block            = "10.0.0.0/16"
    flow_log_traffic_type = "DENY"
  }

  expect_failures = [var.flow_log_traffic_type]
}

run "test_reject_flow_log_traffic_type_lowercase" {
  command = plan

  variables {
    name                  = "test-vpc"
    cidr_block            = "10.0.0.0/16"
    flow_log_traffic_type = "all"
  }

  expect_failures = [var.flow_log_traffic_type]
}

run "test_reject_empty_flow_log_traffic_type" {
  command = plan

  variables {
    name                  = "test-vpc"
    cidr_block            = "10.0.0.0/16"
    flow_log_traffic_type = ""
  }

  expect_failures = [var.flow_log_traffic_type]
}

################################################################################
# flow_log_max_aggregation_interval — Must be 60 or 600
################################################################################

run "test_reject_aggregation_interval_0" {
  command = plan

  variables {
    name                              = "test-vpc"
    cidr_block                        = "10.0.0.0/16"
    flow_log_max_aggregation_interval = 0
  }

  expect_failures = [var.flow_log_max_aggregation_interval]
}

run "test_reject_aggregation_interval_120" {
  command = plan

  variables {
    name                              = "test-vpc"
    cidr_block                        = "10.0.0.0/16"
    flow_log_max_aggregation_interval = 120
  }

  expect_failures = [var.flow_log_max_aggregation_interval]
}

run "test_reject_aggregation_interval_300" {
  command = plan

  variables {
    name                              = "test-vpc"
    cidr_block                        = "10.0.0.0/16"
    flow_log_max_aggregation_interval = 300
  }

  expect_failures = [var.flow_log_max_aggregation_interval]
}

run "test_reject_aggregation_interval_negative" {
  command = plan

  variables {
    name                              = "test-vpc"
    cidr_block                        = "10.0.0.0/16"
    flow_log_max_aggregation_interval = -1
  }

  expect_failures = [var.flow_log_max_aggregation_interval]
}

################################################################################
# instance_tenancy — Must be "default" or "dedicated"
################################################################################

run "test_reject_invalid_instance_tenancy" {
  command = plan

  variables {
    name             = "test-vpc"
    cidr_block       = "10.0.0.0/16"
    instance_tenancy = "host"
  }

  expect_failures = [var.instance_tenancy]
}

run "test_reject_empty_instance_tenancy" {
  command = plan

  variables {
    name             = "test-vpc"
    cidr_block       = "10.0.0.0/16"
    instance_tenancy = ""
  }

  expect_failures = [var.instance_tenancy]
}

run "test_reject_instance_tenancy_wrong_case" {
  command = plan

  variables {
    name             = "test-vpc"
    cidr_block       = "10.0.0.0/16"
    instance_tenancy = "Default"
  }

  expect_failures = [var.instance_tenancy]
}

################################################################################
# flow_log_cloudwatch_log_group_retention_in_days — Allowed values only
################################################################################

run "test_reject_retention_invalid_value_15" {
  command = plan

  variables {
    name                                            = "test-vpc"
    cidr_block                                      = "10.0.0.0/16"
    flow_log_cloudwatch_log_group_retention_in_days = 15
  }

  expect_failures = [var.flow_log_cloudwatch_log_group_retention_in_days]
}

run "test_reject_retention_invalid_value_10" {
  command = plan

  variables {
    name                                            = "test-vpc"
    cidr_block                                      = "10.0.0.0/16"
    flow_log_cloudwatch_log_group_retention_in_days = 10
  }

  expect_failures = [var.flow_log_cloudwatch_log_group_retention_in_days]
}

run "test_reject_retention_invalid_value_31" {
  command = plan

  variables {
    name                                            = "test-vpc"
    cidr_block                                      = "10.0.0.0/16"
    flow_log_cloudwatch_log_group_retention_in_days = 31
  }

  expect_failures = [var.flow_log_cloudwatch_log_group_retention_in_days]
}

run "test_reject_retention_negative" {
  command = plan

  variables {
    name                                            = "test-vpc"
    cidr_block                                      = "10.0.0.0/16"
    flow_log_cloudwatch_log_group_retention_in_days = -1
  }

  expect_failures = [var.flow_log_cloudwatch_log_group_retention_in_days]
}

run "test_reject_retention_large_invalid_value" {
  command = plan

  variables {
    name                                            = "test-vpc"
    cidr_block                                      = "10.0.0.0/16"
    flow_log_cloudwatch_log_group_retention_in_days = 9999
  }

  expect_failures = [var.flow_log_cloudwatch_log_group_retention_in_days]
}
