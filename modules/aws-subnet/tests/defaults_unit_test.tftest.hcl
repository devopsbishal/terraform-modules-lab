mock_provider "aws" {}

run "defaults_are_sensible" {
  command = plan

  variables {
    availability_zone = "us-east-1a"
    cidr_block        = "10.0.0.0/24"
    vpc_id            = "vpc-1092"
  }

  assert {
    condition     = aws_subnet.this.map_public_ip_on_launch == false
    error_message = "map_public_ip_on_launch should default to false."
  }

  assert {
    condition     = aws_subnet.this.tags["Name"] == "terraform-subnet"
    error_message = "Default Name tag should be 'terraform-subnet'."
  }

  assert {
    condition     = aws_subnet.this.vpc_id == "vpc-1092"
    error_message = "vpc_id should pass through to the subnet resource."
  }

  assert {
    condition     = aws_subnet.this.availability_zone == "us-east-1a"
    error_message = "availability_zone should pass through to the subnet resource."
  }

  assert {
    condition     = aws_subnet.this.cidr_block == "10.0.0.0/24"
    error_message = "cidr_block should pass through to the subnet resource."
  }

  assert {
    condition     = length(aws_subnet.this.tags) == 1
    error_message = "With no custom tags, exactly 1 tag (Name) should be present."
  }
}

run "map_public_ip_on_launch_enabled" {
  command = plan

  variables {
    availability_zone = "us-east-1a"
    cidr_block        = "10.0.0.0/24"
    vpc_id            = "vpc-1092"
    map_public_ip_on_launch = true
  }

  assert {
    condition     = aws_subnet.this.map_public_ip_on_launch == true
    error_message = "map_public_ip_on_launch should be true when explicitly enabled."
  }
}

run "custom_name_lands_in_tag" {
  command = plan

  variables {
    availability_zone = "us-east-1a"
    cidr_block        = "10.0.0.0/24"
    vpc_id            = "vpc-1092"
    name              = "my-custom-subnet"
  }

  assert {
    condition     = aws_subnet.this.tags["Name"] == "my-custom-subnet"
    error_message = "Custom name should appear in the Name tag."
  }
}

run "custom_tags_merge_with_name" {
  command = plan

  variables {
    availability_zone = "us-east-1a"
    cidr_block        = "10.0.0.0/24"
    vpc_id            = "vpc-1092"
    name              = "tagged-subnet"
    tags = {
      Environment = "test"
      Team        = "platform"
    }
  }

  assert {
    condition     = aws_subnet.this.tags["Name"] == "tagged-subnet"
    error_message = "Name tag should still be set when custom tags are provided."
  }

  assert {
    condition     = aws_subnet.this.tags["Environment"] == "test"
    error_message = "Custom tags should be merged onto the subnet resource."
  }

  assert {
    condition     = aws_subnet.this.tags["Team"] == "platform"
    error_message = "All custom tags should be present on the subnet resource."
  }
}

run "user_name_tag_overrides_default" {
  command = plan

  variables {
    availability_zone = "us-east-1a"
    cidr_block        = "10.0.0.0/24"
    vpc_id            = "vpc-1092"
    name              = "default-name"
    tags = {
      Name = "override-name"
    }
  }

  assert {
    condition     = aws_subnet.this.tags["Name"] == "override-name"
    error_message = "A Name key in var.tags should override the name set by var.name due to merge precedence."
  }
}

run "accepts_long_form_vpc_id" {
  command = plan

  variables {
    availability_zone = "us-east-1a"
    cidr_block        = "10.0.0.0/24"
    vpc_id            = "vpc-0abcdef1234567890"
  }

  assert {
    condition     = aws_subnet.this.vpc_id == "vpc-0abcdef1234567890"
    error_message = "Long-form VPC IDs should be accepted and passed through."
  }
}
