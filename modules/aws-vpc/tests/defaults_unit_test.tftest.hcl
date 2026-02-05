mock_provider "aws" {}

run "defaults_are_sensible" {
  command = plan

  variables {
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.this.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR block didn't match input."
  }

  assert {
    condition     = aws_vpc.this.enable_dns_support == true
    error_message = "DNS support should default to true."
  }

  assert {
    condition     = aws_vpc.this.enable_dns_hostnames == true
    error_message = "DNS hostnames should default to true."
  }

  assert {
    condition     = aws_vpc.this.tags["Name"] == "terraform-vpc"
    error_message = "Default VPC name tag should be 'terraform-vpc'."
  }

  assert {
    condition     = length(aws_internet_gateway.this) == 1
    error_message = "IGW should be created when create_igw defaults to true."
  }
}

run "igw_not_created_when_flag_false" {
  command = plan

  variables {
    cidr_block = "10.0.0.0/16"
    create_igw = false
  }

  assert {
    condition     = length(aws_internet_gateway.this) == 0
    error_message = "IGW should not be created when create_igw is set to false."
  }
}