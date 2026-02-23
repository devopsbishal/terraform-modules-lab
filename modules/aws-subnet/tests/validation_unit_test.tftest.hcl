mock_provider "aws" {}

run "rejects_empty_cidr_block" {
  command = plan

  variables {
    cidr_block        = ""
    availability_zone = "us-east-1a"
    vpc_id            = "vpc-1092"
  }

  expect_failures = [var.cidr_block]
}

run "rejects_non_cidr_string" {
  command = plan

  variables {
    cidr_block        = "not-a-cidr"
    availability_zone = "us-east-1a"
    vpc_id            = "vpc-1092"
  }

  expect_failures = [var.cidr_block]
}

run "rejects_ip_without_prefix" {
  command = plan

  variables {
    cidr_block        = "10.0.0.0"
    availability_zone = "us-east-1a"
    vpc_id            = "vpc-1092"
  }

  expect_failures = [var.cidr_block]
}

run "rejects_cidr_prefix_out_of_range" {
  command = plan

  variables {
    cidr_block        = "10.0.0.0/33"
    availability_zone = "us-east-1a"
    vpc_id            = "vpc-1092"
  }

  expect_failures = [var.cidr_block]
}

run "rejects_invalid_octet_in_cidr" {
  command = plan

  variables {
    cidr_block        = "256.0.0.0/24"
    availability_zone = "us-east-1a"
    vpc_id            = "vpc-1092"
  }

  expect_failures = [var.cidr_block]
}

run "rejects_empty_vpc_id" {
  command = plan

  variables {
    cidr_block        = "10.0.0.0/24"
    availability_zone = "us-east-1a"
    vpc_id            = ""
  }

  expect_failures = [var.vpc_id]
}

run "rejects_wrong_prefix_in_vpc_id" {
  command = plan

  variables {
    cidr_block        = "10.0.0.0/24"
    availability_zone = "us-east-1a"
    vpc_id            = "subnet-abc123"
  }

  expect_failures = [var.vpc_id]
}

run "rejects_vpc_id_prefix_only" {
  command = plan

  variables {
    cidr_block        = "10.0.0.0/24"
    availability_zone = "us-east-1a"
    vpc_id            = "vpc-"
  }

  expect_failures = [var.vpc_id]
}

run "rejects_vpc_id_with_non_hex_chars" {
  command = plan

  variables {
    cidr_block        = "10.0.0.0/24"
    availability_zone = "us-east-1a"
    vpc_id            = "vpc-GHIJK"
  }

  expect_failures = [var.vpc_id]
}

run "rejects_vpc_id_with_uppercase_hex" {
  command = plan

  variables {
    cidr_block        = "10.0.0.0/24"
    availability_zone = "us-east-1a"
    vpc_id            = "vpc-0AbC"
  }

  expect_failures = [var.vpc_id]
}

run "rejects_empty_availability_zone" {
  command = plan

  variables {
    cidr_block        = "10.0.0.0/24"
    availability_zone = ""
    vpc_id            = "vpc-1092"
  }

  expect_failures = [var.availability_zone]
}

run "rejects_invalid_availability_zone_format" {
  command = plan

  variables {
    cidr_block        = "10.0.0.0/24"
    availability_zone = "invalid-az"
    vpc_id            = "vpc-1092"
  }

  expect_failures = [var.availability_zone]
}

run "rejects_availability_zone_missing_letter_suffix" {
  command = plan

  variables {
    cidr_block        = "10.0.0.0/24"
    availability_zone = "us-east-1"
    vpc_id            = "vpc-1092"
  }

  expect_failures = [var.availability_zone]
}

run "rejects_empty_name" {
  command = plan

  variables {
    cidr_block        = "10.0.0.0/24"
    availability_zone = "us-east-1a"
    vpc_id            = "vpc-1092"
    name              = ""
  }

  expect_failures = [var.name]
}
