################################################################################
# Full Integration Test — AWS VPC Module
#
# Deploys REAL AWS resources using command = apply and validates every resource
# the module can create: VPC, Internet Gateway, default security group lockdown,
# VPC Flow Logs (CloudWatch destination), CloudWatch Log Group, IAM Role, and
# IAM Role Policy.
#
# Prerequisites:
#   - Valid AWS credentials with permissions to create VPC, IGW, CloudWatch,
#     IAM, and Flow Log resources
#   - Runs in us-east-1
#
# Resources are auto-created and auto-destroyed by terraform test.
#
# Note: Sequential run blocks share state. Each run replaces the previous one's
# resources, which also exercises the destroy path for conditional resources
# (e.g., when moving from a full-featured VPC to a minimal one, the IGW, flow
# log, IAM role, etc. are destroyed before the new VPC is created).
################################################################################

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      ManagedBy = "terraform-test"
      TestSuite = "full-integration"
    }
  }
}

################################################################################
# 1. Full Feature Deploy — Create all resources with all features enabled
################################################################################

run "test_full_featured_vpc" {
  command = apply

  variables {
    name                                            = "integ-test-vpc"
    cidr_block                                      = "10.99.0.0/16"
    create_igw                                      = true
    enable_dns_hostnames                            = true
    enable_dns_support                              = true
    enable_network_address_usage_metrics            = true
    assign_generated_ipv6_cidr_block                = false
    instance_tenancy                                = "default"
    manage_default_security_group                   = true
    flow_log_enabled                                = true
    flow_log_destination_type                       = "cloud-watch-logs"
    flow_log_traffic_type                           = "ALL"
    flow_log_max_aggregation_interval               = 600
    flow_log_cloudwatch_log_group_retention_in_days = 1
    tags = {
      Environment = "integration-test"
      Project     = "terraform-modules-lab"
    }
  }

  ############################################################################
  # VPC Core Assertions
  ############################################################################

  # Verify VPC ID is a real AWS VPC ID
  assert {
    condition     = can(regex("^vpc-[0-9a-f]+$", aws_vpc.this.id))
    error_message = "Expected VPC ID to match 'vpc-*' pattern, got '${aws_vpc.this.id}'."
  }

  # Verify VPC ARN is a real AWS ARN
  assert {
    condition     = can(regex("^arn:aws:ec2:us-east-1:[0-9]{12}:vpc/vpc-", aws_vpc.this.arn))
    error_message = "Expected VPC ARN to be a valid us-east-1 ARN, got '${aws_vpc.this.arn}'."
  }

  # Verify CIDR block matches what we requested
  assert {
    condition     = aws_vpc.this.cidr_block == "10.99.0.0/16"
    error_message = "Expected VPC CIDR to be '10.99.0.0/16', got '${aws_vpc.this.cidr_block}'."
  }

  # Verify DNS support is enabled
  assert {
    condition     = aws_vpc.this.enable_dns_support == true
    error_message = "Expected DNS support to be enabled on the VPC."
  }

  # Verify DNS hostnames is enabled
  assert {
    condition     = aws_vpc.this.enable_dns_hostnames == true
    error_message = "Expected DNS hostnames to be enabled on the VPC."
  }

  # Verify instance tenancy
  assert {
    condition     = aws_vpc.this.instance_tenancy == "default"
    error_message = "Expected instance tenancy to be 'default', got '${aws_vpc.this.instance_tenancy}'."
  }

  # Verify NAU metrics enabled
  assert {
    condition     = aws_vpc.this.enable_network_address_usage_metrics == true
    error_message = "Expected NAU metrics to be enabled on the VPC."
  }

  # Verify Name tag
  assert {
    condition     = aws_vpc.this.tags["Name"] == "integ-test-vpc"
    error_message = "Expected VPC Name tag to be 'integ-test-vpc', got '${aws_vpc.this.tags["Name"]}'."
  }

  # Verify custom tags are applied
  assert {
    condition     = aws_vpc.this.tags["Environment"] == "integration-test"
    error_message = "Expected VPC Environment tag to be 'integration-test'."
  }

  assert {
    condition     = aws_vpc.this.tags["Project"] == "terraform-modules-lab"
    error_message = "Expected VPC Project tag to be 'terraform-modules-lab'."
  }

  # Verify default resources were created by AWS alongside the VPC
  assert {
    condition     = can(regex("^rtb-[0-9a-f]+$", aws_vpc.this.default_route_table_id))
    error_message = "Expected default route table ID to be populated."
  }

  assert {
    condition     = can(regex("^acl-[0-9a-f]+$", aws_vpc.this.default_network_acl_id))
    error_message = "Expected default network ACL ID to be populated."
  }

  assert {
    condition     = can(regex("^sg-[0-9a-f]+$", aws_vpc.this.default_security_group_id))
    error_message = "Expected default security group ID to be populated."
  }

  # Verify owner ID is a 12-digit AWS account ID
  assert {
    condition     = can(regex("^[0-9]{12}$", aws_vpc.this.owner_id))
    error_message = "Expected VPC owner_id to be a 12-digit account ID, got '${aws_vpc.this.owner_id}'."
  }

  ############################################################################
  # Internet Gateway Assertions
  ############################################################################

  # Verify IGW was created
  assert {
    condition     = length(aws_internet_gateway.this) == 1
    error_message = "Expected exactly one Internet Gateway to be created."
  }

  # Verify IGW has a real AWS ID
  assert {
    condition     = can(regex("^igw-[0-9a-f]+$", aws_internet_gateway.this[0].id))
    error_message = "Expected IGW ID to match 'igw-*' pattern, got '${aws_internet_gateway.this[0].id}'."
  }

  # Verify IGW is attached to the correct VPC
  assert {
    condition     = aws_internet_gateway.this[0].vpc_id == aws_vpc.this.id
    error_message = "Expected IGW to be attached to the VPC."
  }

  # Verify IGW Name tag
  assert {
    condition     = aws_internet_gateway.this[0].tags["Name"] == "integ-test-vpc-igw"
    error_message = "Expected IGW Name tag to be 'integ-test-vpc-igw', got '${aws_internet_gateway.this[0].tags["Name"]}'."
  }

  # Verify custom tags propagated to IGW
  assert {
    condition     = aws_internet_gateway.this[0].tags["Environment"] == "integration-test"
    error_message = "Expected custom Environment tag to propagate to IGW."
  }

  ############################################################################
  # Default Security Group Lockdown Assertions
  ############################################################################

  # Verify default SG is managed
  assert {
    condition     = length(aws_default_security_group.this) == 1
    error_message = "Expected default security group to be managed."
  }

  # Verify default SG has a real AWS ID
  assert {
    condition     = can(regex("^sg-[0-9a-f]+$", aws_default_security_group.this[0].id))
    error_message = "Expected default SG ID to match 'sg-*' pattern."
  }

  # Verify default SG is associated with the correct VPC
  assert {
    condition     = aws_default_security_group.this[0].vpc_id == aws_vpc.this.id
    error_message = "Expected default SG to belong to the VPC."
  }

  # Verify default SG Name tag
  assert {
    condition     = aws_default_security_group.this[0].tags["Name"] == "integ-test-vpc-default-sg"
    error_message = "Expected default SG Name tag to be 'integ-test-vpc-default-sg'."
  }

  # Verify default SG has NO ingress rules (locked down)
  assert {
    condition     = length(aws_default_security_group.this[0].ingress) == 0
    error_message = "Expected default security group to have zero ingress rules (locked down)."
  }

  # Verify default SG has NO egress rules (locked down)
  assert {
    condition     = length(aws_default_security_group.this[0].egress) == 0
    error_message = "Expected default security group to have zero egress rules (locked down)."
  }

  ############################################################################
  # VPC Flow Log Assertions
  ############################################################################

  # Verify flow log was created
  assert {
    condition     = length(aws_flow_log.this) == 1
    error_message = "Expected exactly one VPC flow log to be created."
  }

  # Verify flow log has a real AWS ID
  assert {
    condition     = can(regex("^fl-[0-9a-f]+$", aws_flow_log.this[0].id))
    error_message = "Expected flow log ID to match 'fl-*' pattern, got '${aws_flow_log.this[0].id}'."
  }

  # Verify flow log is attached to the correct VPC
  assert {
    condition     = aws_flow_log.this[0].vpc_id == aws_vpc.this.id
    error_message = "Expected flow log to be attached to the VPC."
  }

  # Verify flow log destination type
  assert {
    condition     = aws_flow_log.this[0].log_destination_type == "cloud-watch-logs"
    error_message = "Expected flow log destination type to be 'cloud-watch-logs', got '${aws_flow_log.this[0].log_destination_type}'."
  }

  # Verify flow log traffic type
  assert {
    condition     = aws_flow_log.this[0].traffic_type == "ALL"
    error_message = "Expected flow log traffic type to be 'ALL', got '${aws_flow_log.this[0].traffic_type}'."
  }

  # Verify flow log aggregation interval
  assert {
    condition     = aws_flow_log.this[0].max_aggregation_interval == 600
    error_message = "Expected flow log aggregation interval to be 600, got ${aws_flow_log.this[0].max_aggregation_interval}."
  }

  # Verify flow log destination points to the auto-created CloudWatch Log Group
  assert {
    condition     = aws_flow_log.this[0].log_destination == aws_cloudwatch_log_group.flow_log[0].arn
    error_message = "Expected flow log destination to match the auto-created CloudWatch Log Group ARN."
  }

  # Verify flow log IAM role points to the auto-created IAM role
  assert {
    condition     = aws_flow_log.this[0].iam_role_arn == aws_iam_role.flow_log[0].arn
    error_message = "Expected flow log IAM role ARN to match the auto-created IAM role ARN."
  }

  # Verify flow log Name tag
  assert {
    condition     = aws_flow_log.this[0].tags["Name"] == "integ-test-vpc-flow-log"
    error_message = "Expected flow log Name tag to be 'integ-test-vpc-flow-log'."
  }

  ############################################################################
  # CloudWatch Log Group Assertions
  ############################################################################

  # Verify CloudWatch Log Group was created
  assert {
    condition     = length(aws_cloudwatch_log_group.flow_log) == 1
    error_message = "Expected exactly one CloudWatch Log Group to be created."
  }

  # Verify Log Group name follows the expected pattern
  assert {
    condition     = aws_cloudwatch_log_group.flow_log[0].name == "/aws/vpc-flow-log/${aws_vpc.this.id}"
    error_message = "Expected Log Group name to be '/aws/vpc-flow-log/${aws_vpc.this.id}'."
  }

  # Verify Log Group ARN is a valid CloudWatch Logs ARN
  assert {
    condition     = can(regex("^arn:aws:logs:us-east-1:[0-9]{12}:log-group:", aws_cloudwatch_log_group.flow_log[0].arn))
    error_message = "Expected Log Group ARN to be a valid us-east-1 CloudWatch Logs ARN."
  }

  # Verify retention period
  assert {
    condition     = aws_cloudwatch_log_group.flow_log[0].retention_in_days == 1
    error_message = "Expected Log Group retention to be 1 day, got ${aws_cloudwatch_log_group.flow_log[0].retention_in_days}."
  }

  # Verify no KMS key (not provided)
  assert {
    condition     = aws_cloudwatch_log_group.flow_log[0].kms_key_id == null || aws_cloudwatch_log_group.flow_log[0].kms_key_id == ""
    error_message = "Expected Log Group to have no KMS key configured."
  }

  # Verify custom tags on Log Group
  assert {
    condition     = aws_cloudwatch_log_group.flow_log[0].tags["Environment"] == "integration-test"
    error_message = "Expected custom Environment tag to propagate to CloudWatch Log Group."
  }

  ############################################################################
  # IAM Role Assertions
  ############################################################################

  # Verify IAM role was created
  assert {
    condition     = length(aws_iam_role.flow_log) == 1
    error_message = "Expected exactly one IAM role to be created for flow logs."
  }

  # Verify IAM role name
  assert {
    condition     = aws_iam_role.flow_log[0].name == "integ-test-vpc-vpc-flow-log-role"
    error_message = "Expected IAM role name to be 'integ-test-vpc-vpc-flow-log-role', got '${aws_iam_role.flow_log[0].name}'."
  }

  # Verify IAM role ARN is a valid IAM ARN
  assert {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/integ-test-vpc-vpc-flow-log-role$", aws_iam_role.flow_log[0].arn))
    error_message = "Expected IAM role ARN to match expected pattern, got '${aws_iam_role.flow_log[0].arn}'."
  }

  # Verify IAM role has correct tags
  assert {
    condition     = aws_iam_role.flow_log[0].tags["Name"] == "integ-test-vpc"
    error_message = "Expected IAM role Name tag to be 'integ-test-vpc'."
  }

  assert {
    condition     = aws_iam_role.flow_log[0].tags["Environment"] == "integration-test"
    error_message = "Expected custom Environment tag to propagate to IAM role."
  }

  ############################################################################
  # IAM Role Policy Assertions
  ############################################################################

  # Verify IAM role policy was created
  assert {
    condition     = length(aws_iam_role_policy.flow_log) == 1
    error_message = "Expected exactly one IAM role policy to be created."
  }

  # Verify IAM role policy name
  assert {
    condition     = aws_iam_role_policy.flow_log[0].name == "integ-test-vpc-vpc-flow-log-policy"
    error_message = "Expected IAM role policy name to be 'integ-test-vpc-vpc-flow-log-policy', got '${aws_iam_role_policy.flow_log[0].name}'."
  }

  # Verify IAM role policy is attached to the correct role
  assert {
    condition     = aws_iam_role_policy.flow_log[0].role == aws_iam_role.flow_log[0].id
    error_message = "Expected IAM role policy to be attached to the flow log IAM role."
  }

  ############################################################################
  # Output Assertions
  ############################################################################

  # Verify vpc_id output matches the VPC resource
  assert {
    condition     = output.vpc_id == aws_vpc.this.id
    error_message = "Expected vpc_id output to match VPC resource ID."
  }

  # Verify vpc_arn output matches the VPC resource
  assert {
    condition     = output.vpc_arn == aws_vpc.this.arn
    error_message = "Expected vpc_arn output to match VPC resource ARN."
  }

  # Verify vpc_cidr_block output
  assert {
    condition     = output.vpc_cidr_block == "10.99.0.0/16"
    error_message = "Expected vpc_cidr_block output to be '10.99.0.0/16'."
  }

  # Verify internet_gateway_id output
  assert {
    condition     = output.internet_gateway_id == aws_internet_gateway.this[0].id
    error_message = "Expected internet_gateway_id output to match IGW resource ID."
  }

  # Verify default_security_group_id output
  assert {
    condition     = can(regex("^sg-[0-9a-f]+$", output.default_security_group_id))
    error_message = "Expected default_security_group_id output to be a valid SG ID."
  }

  # Verify default_route_table_id output
  assert {
    condition     = can(regex("^rtb-[0-9a-f]+$", output.default_route_table_id))
    error_message = "Expected default_route_table_id output to be a valid route table ID."
  }

  # Verify default_network_acl_id output
  assert {
    condition     = can(regex("^acl-[0-9a-f]+$", output.default_network_acl_id))
    error_message = "Expected default_network_acl_id output to be a valid ACL ID."
  }

  # Verify main_route_table_id output
  assert {
    condition     = can(regex("^rtb-[0-9a-f]+$", output.main_route_table_id))
    error_message = "Expected main_route_table_id output to be a valid route table ID."
  }

  # Verify owner_id output
  assert {
    condition     = can(regex("^[0-9]{12}$", output.owner_id))
    error_message = "Expected owner_id output to be a 12-digit account ID."
  }

  # Verify flow_log_id output
  assert {
    condition     = output.flow_log_id == aws_flow_log.this[0].id
    error_message = "Expected flow_log_id output to match flow log resource ID."
  }

  # Verify flow_log_cloudwatch_log_group_arn output
  assert {
    condition     = output.flow_log_cloudwatch_log_group_arn == aws_cloudwatch_log_group.flow_log[0].arn
    error_message = "Expected flow_log_cloudwatch_log_group_arn output to match Log Group ARN."
  }

  # Verify flow_log_iam_role_arn output
  assert {
    condition     = output.flow_log_iam_role_arn == aws_iam_role.flow_log[0].arn
    error_message = "Expected flow_log_iam_role_arn output to match IAM role ARN."
  }
}

################################################################################
# 2. Minimal Deploy — VPC only, all optional features disabled
################################################################################

run "test_minimal_vpc" {
  command = apply

  variables {
    name                          = "integ-test-minimal"
    cidr_block                    = "10.98.0.0/20"
    create_igw                    = false
    manage_default_security_group = false
    flow_log_enabled              = false
    enable_dns_hostnames          = false
    enable_dns_support            = false
  }

  # Verify VPC was created with correct CIDR
  assert {
    condition     = aws_vpc.this.cidr_block == "10.98.0.0/20"
    error_message = "Expected minimal VPC CIDR to be '10.98.0.0/20', got '${aws_vpc.this.cidr_block}'."
  }

  # Verify DNS settings are disabled
  assert {
    condition     = aws_vpc.this.enable_dns_support == false
    error_message = "Expected DNS support to be disabled on minimal VPC."
  }

  assert {
    condition     = aws_vpc.this.enable_dns_hostnames == false
    error_message = "Expected DNS hostnames to be disabled on minimal VPC."
  }

  # Verify no IGW was created
  assert {
    condition     = length(aws_internet_gateway.this) == 0
    error_message = "Expected no IGW in minimal deployment."
  }

  # Verify no default SG management
  assert {
    condition     = length(aws_default_security_group.this) == 0
    error_message = "Expected no managed default SG in minimal deployment."
  }

  # Verify no flow log resources
  assert {
    condition     = length(aws_flow_log.this) == 0
    error_message = "Expected no flow log in minimal deployment."
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.flow_log) == 0
    error_message = "Expected no CloudWatch Log Group in minimal deployment."
  }

  assert {
    condition     = length(aws_iam_role.flow_log) == 0
    error_message = "Expected no IAM role in minimal deployment."
  }

  assert {
    condition     = length(aws_iam_role_policy.flow_log) == 0
    error_message = "Expected no IAM role policy in minimal deployment."
  }

  # Verify outputs for disabled features are null
  assert {
    condition     = output.internet_gateway_id == null
    error_message = "Expected internet_gateway_id output to be null in minimal deployment."
  }

  assert {
    condition     = output.flow_log_id == null
    error_message = "Expected flow_log_id output to be null in minimal deployment."
  }

  assert {
    condition     = output.flow_log_cloudwatch_log_group_arn == null
    error_message = "Expected flow_log_cloudwatch_log_group_arn output to be null in minimal deployment."
  }

  assert {
    condition     = output.flow_log_iam_role_arn == null
    error_message = "Expected flow_log_iam_role_arn output to be null in minimal deployment."
  }
}

################################################################################
# 3. Flow Log with 60-second aggregation — Test non-default flow log setting
################################################################################

run "test_flow_log_fast_aggregation" {
  command = apply

  variables {
    name                                            = "integ-test-fast-fl"
    cidr_block                                      = "10.97.0.0/20"
    create_igw                                      = false
    manage_default_security_group                   = false
    flow_log_enabled                                = true
    flow_log_traffic_type                           = "REJECT"
    flow_log_max_aggregation_interval               = 60
    flow_log_cloudwatch_log_group_retention_in_days = 1
  }

  # Verify flow log was created with 60-second aggregation
  assert {
    condition     = aws_flow_log.this[0].max_aggregation_interval == 60
    error_message = "Expected flow log aggregation interval to be 60, got ${aws_flow_log.this[0].max_aggregation_interval}."
  }

  # Verify REJECT-only traffic capture
  assert {
    condition     = aws_flow_log.this[0].traffic_type == "REJECT"
    error_message = "Expected flow log traffic type to be 'REJECT', got '${aws_flow_log.this[0].traffic_type}'."
  }

  # Verify CloudWatch Log Group was auto-created
  assert {
    condition     = length(aws_cloudwatch_log_group.flow_log) == 1
    error_message = "Expected CloudWatch Log Group to be auto-created for cloud-watch-logs destination."
  }

  # Verify IAM role was auto-created
  assert {
    condition     = length(aws_iam_role.flow_log) == 1
    error_message = "Expected IAM role to be auto-created for cloud-watch-logs destination."
  }

  # Verify Log Group name includes the VPC ID
  assert {
    condition     = aws_cloudwatch_log_group.flow_log[0].name == "/aws/vpc-flow-log/${aws_vpc.this.id}"
    error_message = "Expected Log Group name to include the VPC ID."
  }
}

################################################################################
# 4. IPv6 Deploy — VPC with Amazon-provided IPv6 CIDR block
################################################################################

run "test_ipv6_vpc" {
  command = apply

  variables {
    name                             = "integ-test-ipv6"
    cidr_block                       = "10.96.0.0/20"
    assign_generated_ipv6_cidr_block = true
    create_igw                       = false
    manage_default_security_group    = false
    flow_log_enabled                 = false
  }

  # Verify VPC was created with correct IPv4 CIDR
  assert {
    condition     = aws_vpc.this.cidr_block == "10.96.0.0/20"
    error_message = "Expected VPC CIDR to be '10.96.0.0/20', got '${aws_vpc.this.cidr_block}'."
  }

  # Verify IPv6 was requested on the VPC resource
  assert {
    condition     = aws_vpc.this.assign_generated_ipv6_cidr_block == true
    error_message = "Expected assign_generated_ipv6_cidr_block to be true on the VPC resource."
  }

  # Verify AWS assigned an IPv6 CIDR block (Amazon-provided /56)
  assert {
    condition     = aws_vpc.this.ipv6_cidr_block != null && aws_vpc.this.ipv6_cidr_block != ""
    error_message = "Expected VPC to have an IPv6 CIDR block assigned by AWS."
  }

  # Verify the IPv6 CIDR block looks like a valid /56
  assert {
    condition     = can(regex("::/56$", aws_vpc.this.ipv6_cidr_block))
    error_message = "Expected IPv6 CIDR block to be a /56 prefix, got '${aws_vpc.this.ipv6_cidr_block}'."
  }

  # Verify IPv6 association ID is populated
  assert {
    condition     = aws_vpc.this.ipv6_association_id != null && aws_vpc.this.ipv6_association_id != ""
    error_message = "Expected IPv6 association ID to be populated when IPv6 is enabled."
  }

  # Verify ipv6_cidr_block output matches the VPC resource
  assert {
    condition     = output.ipv6_cidr_block == aws_vpc.this.ipv6_cidr_block
    error_message = "Expected ipv6_cidr_block output to match the VPC resource's IPv6 CIDR block."
  }

  # Verify ipv6_association_id output matches the VPC resource
  assert {
    condition     = output.ipv6_association_id == aws_vpc.this.ipv6_association_id
    error_message = "Expected ipv6_association_id output to match the VPC resource's IPv6 association ID."
  }
}
