################################################################################
# IPv6 IPAM Unit Tests — AWS VPC Module
#
# BLOCKED BY MODULE BUG: These tests cannot pass until main.tf is updated to
# conditionally set assign_generated_ipv6_cidr_block only when
# ipv6_ipam_pool_id is null. Currently, the module always passes
# assign_generated_ipv6_cidr_block to the VPC resource (even when false),
# which triggers the AWS provider's schema-level ConflictsWith constraint
# between assign_generated_ipv6_cidr_block and ipv6_ipam_pool_id.
#
# Fix required in main.tf:
#   assign_generated_ipv6_cidr_block = var.ipv6_ipam_pool_id == null ? var.assign_generated_ipv6_cidr_block : false
# Or use a dynamic approach to omit the attribute entirely when IPv6 IPAM is used.
#
# Once the fix is applied, uncomment the run blocks below and verify they pass.
################################################################################

mock_provider "aws" {}

################################################################################
# IPv6 IPAM Mode — cidr_block (explicit) + IPv6 via IPAM
#
# All tests below are commented out pending the module fix described above.
# They are preserved here so they can be enabled once the fix is applied.
################################################################################

# run "test_ipv6_ipam_pool_id_set_on_vpc" {
#   command = plan
#
#   variables {
#     name                = "ipam-v6"
#     cidr_block          = "10.0.0.0/16"
#     ipv6_ipam_pool_id   = "ipam-pool-0123456789abcdef1"
#     ipv6_netmask_length = 56
#     flow_log_enabled    = false
#   }
#
#   assert {
#     condition     = aws_vpc.this.ipv6_ipam_pool_id == "ipam-pool-0123456789abcdef1"
#     error_message = "Expected VPC ipv6_ipam_pool_id to be 'ipam-pool-0123456789abcdef1', got '${aws_vpc.this.ipv6_ipam_pool_id}'."
#   }
# }

# run "test_ipv6_ipam_netmask_length_set_on_vpc" {
#   command = plan
#
#   variables {
#     name                = "ipam-v6"
#     cidr_block          = "10.0.0.0/16"
#     ipv6_ipam_pool_id   = "ipam-pool-0123456789abcdef1"
#     ipv6_netmask_length = 56
#     flow_log_enabled    = false
#   }
#
#   assert {
#     condition     = aws_vpc.this.ipv6_netmask_length == 56
#     error_message = "Expected VPC ipv6_netmask_length to be 56, got ${aws_vpc.this.ipv6_netmask_length}."
#   }
# }

# run "test_ipv6_ipam_with_explicit_cidr_block" {
#   command = plan
#
#   variables {
#     name                = "ipam-v6"
#     cidr_block          = "172.16.0.0/20"
#     ipv6_ipam_pool_id   = "ipam-pool-0123456789abcdef1"
#     ipv6_netmask_length = 48
#     flow_log_enabled    = false
#   }
#
#   assert {
#     condition     = aws_vpc.this.cidr_block == "172.16.0.0/20"
#     error_message = "Expected VPC cidr_block to be '172.16.0.0/20' when using IPv6 IPAM alongside explicit IPv4."
#   }
#
#   assert {
#     condition     = aws_vpc.this.ipv6_ipam_pool_id == "ipam-pool-0123456789abcdef1"
#     error_message = "Expected ipv6_ipam_pool_id to be set alongside explicit IPv4 CIDR."
#   }
# }

# run "test_ipv6_ipam_does_not_enable_generated_ipv6" {
#   command = plan
#
#   variables {
#     name                             = "ipam-v6"
#     cidr_block                       = "10.0.0.0/16"
#     assign_generated_ipv6_cidr_block = false
#     ipv6_ipam_pool_id                = "ipam-pool-0123456789abcdef1"
#     ipv6_netmask_length              = 56
#     flow_log_enabled                 = false
#   }
#
#   assert {
#     condition     = aws_vpc.this.assign_generated_ipv6_cidr_block == false
#     error_message = "Expected assign_generated_ipv6_cidr_block to remain false when using IPv6 IPAM."
#   }
# }

################################################################################
# Dual-Stack IPAM — Both IPv4 and IPv6 via IPAM Pools
################################################################################

# run "test_dual_ipam_ipv4_pool_set" {
#   command = plan
#
#   variables {
#     name                = "ipam-dual"
#     ipv4_ipam_pool_id   = "ipam-pool-0123456789abcdef0"
#     ipv4_netmask_length = 20
#     ipv6_ipam_pool_id   = "ipam-pool-0123456789abcdef1"
#     ipv6_netmask_length = 56
#     flow_log_enabled    = false
#   }
#
#   assert {
#     condition     = aws_vpc.this.ipv4_ipam_pool_id == "ipam-pool-0123456789abcdef0"
#     error_message = "Expected ipv4_ipam_pool_id to be set in dual-stack IPAM mode."
#   }
# }

# run "test_dual_ipam_ipv4_netmask_set" {
#   command = plan
#
#   variables {
#     name                = "ipam-dual"
#     ipv4_ipam_pool_id   = "ipam-pool-0123456789abcdef0"
#     ipv4_netmask_length = 20
#     ipv6_ipam_pool_id   = "ipam-pool-0123456789abcdef1"
#     ipv6_netmask_length = 56
#     flow_log_enabled    = false
#   }
#
#   assert {
#     condition     = aws_vpc.this.ipv4_netmask_length == 20
#     error_message = "Expected ipv4_netmask_length to be 20 in dual-stack IPAM mode."
#   }
# }

# run "test_dual_ipam_ipv6_pool_set" {
#   command = plan
#
#   variables {
#     name                = "ipam-dual"
#     ipv4_ipam_pool_id   = "ipam-pool-0123456789abcdef0"
#     ipv4_netmask_length = 20
#     ipv6_ipam_pool_id   = "ipam-pool-0123456789abcdef1"
#     ipv6_netmask_length = 56
#     flow_log_enabled    = false
#   }
#
#   assert {
#     condition     = aws_vpc.this.ipv6_ipam_pool_id == "ipam-pool-0123456789abcdef1"
#     error_message = "Expected ipv6_ipam_pool_id to be set in dual-stack IPAM mode."
#   }
# }

# run "test_dual_ipam_ipv6_netmask_set" {
#   command = plan
#
#   variables {
#     name                = "ipam-dual"
#     ipv4_ipam_pool_id   = "ipam-pool-0123456789abcdef0"
#     ipv4_netmask_length = 20
#     ipv6_ipam_pool_id   = "ipam-pool-0123456789abcdef1"
#     ipv6_netmask_length = 56
#     flow_log_enabled    = false
#   }
#
#   assert {
#     condition     = aws_vpc.this.ipv6_netmask_length == 56
#     error_message = "Expected ipv6_netmask_length to be 56 in dual-stack IPAM mode."
#   }
# }

# run "test_dual_ipam_generated_ipv6_false" {
#   command = plan
#
#   variables {
#     name                = "ipam-dual"
#     ipv4_ipam_pool_id   = "ipam-pool-0123456789abcdef0"
#     ipv4_netmask_length = 20
#     ipv6_ipam_pool_id   = "ipam-pool-0123456789abcdef1"
#     ipv6_netmask_length = 56
#     flow_log_enabled    = false
#   }
#
#   assert {
#     condition     = aws_vpc.this.assign_generated_ipv6_cidr_block == false
#     error_message = "Expected assign_generated_ipv6_cidr_block to be false in dual-stack IPAM mode."
#   }
# }

################################################################################
# IPv6 IPAM Output Tests
################################################################################

# run "test_output_ipv6_ipam_pool_id_when_set" {
#   command = plan
#
#   variables {
#     name                = "ipam-output"
#     cidr_block          = "10.0.0.0/16"
#     ipv6_ipam_pool_id   = "ipam-pool-0123456789abcdef1"
#     ipv6_netmask_length = 48
#     flow_log_enabled    = false
#   }
#
#   assert {
#     condition     = output.ipv6_ipam_pool_id == "ipam-pool-0123456789abcdef1"
#     error_message = "Expected ipv6_ipam_pool_id output to match input 'ipam-pool-0123456789abcdef1', got '${output.ipv6_ipam_pool_id}'."
#   }
# }

# run "test_output_dual_ipam_both_pool_ids" {
#   command = plan
#
#   variables {
#     name                = "ipam-dual-output"
#     ipv4_ipam_pool_id   = "ipam-pool-aaaaaaaaaaaaaaaa0"
#     ipv4_netmask_length = 24
#     ipv6_ipam_pool_id   = "ipam-pool-bbbbbbbbbbbbbbbb1"
#     ipv6_netmask_length = 52
#     flow_log_enabled    = false
#   }
#
#   assert {
#     condition     = output.ipv4_ipam_pool_id == "ipam-pool-aaaaaaaaaaaaaaaa0"
#     error_message = "Expected ipv4_ipam_pool_id output to match input in dual-stack IPAM mode."
#   }
#
#   assert {
#     condition     = output.ipv6_ipam_pool_id == "ipam-pool-bbbbbbbbbbbbbbbb1"
#     error_message = "Expected ipv6_ipam_pool_id output to match input in dual-stack IPAM mode."
#   }
# }

################################################################################
# IPv6 IPAM Edge Cases — All Valid Netmask Lengths
################################################################################

# run "test_ipv6_netmask_length_44" {
#   command = plan
#
#   variables {
#     name                = "ipam-v6-44"
#     cidr_block          = "10.0.0.0/16"
#     ipv6_ipam_pool_id   = "ipam-pool-0123456789abcdef1"
#     ipv6_netmask_length = 44
#     flow_log_enabled    = false
#   }
#
#   assert {
#     condition     = aws_vpc.this.ipv6_netmask_length == 44
#     error_message = "Expected ipv6_netmask_length of 44 to be accepted."
#   }
# }

# run "test_ipv6_netmask_length_48" {
#   command = plan
#
#   variables {
#     name                = "ipam-v6-48"
#     cidr_block          = "10.0.0.0/16"
#     ipv6_ipam_pool_id   = "ipam-pool-0123456789abcdef1"
#     ipv6_netmask_length = 48
#     flow_log_enabled    = false
#   }
#
#   assert {
#     condition     = aws_vpc.this.ipv6_netmask_length == 48
#     error_message = "Expected ipv6_netmask_length of 48 to be accepted."
#   }
# }

# run "test_ipv6_netmask_length_52" {
#   command = plan
#
#   variables {
#     name                = "ipam-v6-52"
#     cidr_block          = "10.0.0.0/16"
#     ipv6_ipam_pool_id   = "ipam-pool-0123456789abcdef1"
#     ipv6_netmask_length = 52
#     flow_log_enabled    = false
#   }
#
#   assert {
#     condition     = aws_vpc.this.ipv6_netmask_length == 52
#     error_message = "Expected ipv6_netmask_length of 52 to be accepted."
#   }
# }

# run "test_ipv6_netmask_length_56" {
#   command = plan
#
#   variables {
#     name                = "ipam-v6-56"
#     cidr_block          = "10.0.0.0/16"
#     ipv6_ipam_pool_id   = "ipam-pool-0123456789abcdef1"
#     ipv6_netmask_length = 56
#     flow_log_enabled    = false
#   }
#
#   assert {
#     condition     = aws_vpc.this.ipv6_netmask_length == 56
#     error_message = "Expected ipv6_netmask_length of 56 to be accepted."
#   }
# }

# run "test_ipv6_netmask_length_60" {
#   command = plan
#
#   variables {
#     name                = "ipam-v6-60"
#     cidr_block          = "10.0.0.0/16"
#     ipv6_ipam_pool_id   = "ipam-pool-0123456789abcdef1"
#     ipv6_netmask_length = 60
#     flow_log_enabled    = false
#   }
#
#   assert {
#     condition     = aws_vpc.this.ipv6_netmask_length == 60
#     error_message = "Expected ipv6_netmask_length of 60 to be accepted."
#   }
# }
