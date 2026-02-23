mock_provider "aws" {}
run "rejects_cidr_prefix_shorter_than_16" {
  command = plan

  variables {
    cidr_block = "10.0.0.0/8"
  }

  expect_failures = [var.cidr_block]
}

run "rejects_cidr_prefix_longer_than_24" {
  command = plan

  variables {
    cidr_block = "10.0.0.0/28"
  }

  expect_failures = [var.cidr_block]
}
