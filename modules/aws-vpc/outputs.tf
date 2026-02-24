output "default_network_acl_id" {
  description = "The ID of the default network ACL created with the VPC."
  value       = aws_vpc.this.default_network_acl_id
}

output "default_route_table_id" {
  description = "The ID of the default route table created with the VPC."
  value       = aws_vpc.this.default_route_table_id
}

output "default_security_group_id" {
  description = "The ID of the VPC's default security group."
  value       = aws_vpc.this.default_security_group_id
}

output "flow_log_cloudwatch_log_group_arn" {
  description = "The ARN of the CloudWatch Log Group for VPC flow logs, if created."
  value       = local.create_flow_log_log_group ? aws_cloudwatch_log_group.flow_log[0].arn : null
}

output "flow_log_iam_role_arn" {
  description = "The ARN of the IAM role used by VPC flow logs. Returns the auto-created role ARN, the user-provided role ARN, or null."
  value       = local.create_flow_log_iam_role ? aws_iam_role.flow_log[0].arn : var.flow_log_iam_role_arn
}

output "flow_log_id" {
  description = "The ID of the VPC flow log, if created."
  value       = local.create_flow_log ? aws_flow_log.this[0].id : null
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway, if created."
  value       = var.create_igw ? aws_internet_gateway.this[0].id : null
}

output "ipv6_association_id" {
  description = "The association ID for the IPv6 CIDR block."
  value       = aws_vpc.this.ipv6_association_id
}

output "ipv6_cidr_block" {
  description = "The IPv6 CIDR block of the VPC, if IPv6 is enabled."
  value       = aws_vpc.this.ipv6_cidr_block
}

output "main_route_table_id" {
  description = "The ID of the main route table associated with the VPC."
  value       = aws_vpc.this.main_route_table_id
}

output "owner_id" {
  description = "The AWS account ID of the VPC owner."
  value       = aws_vpc.this.owner_id
}

output "vpc_arn" {
  description = "The ARN of the VPC."
  value       = aws_vpc.this.arn
}

output "vpc_cidr_block" {
  description = "The IPv4 CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "vpc_id" {
  description = "The ID of the VPC."
  value       = aws_vpc.this.id
}
