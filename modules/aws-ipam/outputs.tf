output "custom_scope_arns" {
  description = "A map of custom scope names to their ARNs."
  value       = { for k, v in aws_vpc_ipam_scope.this : k => v.arn }
}

output "custom_scope_ids" {
  description = "A map of custom scope names to their IDs."
  value       = { for k, v in aws_vpc_ipam_scope.this : k => v.id }
}

output "custom_scope_types" {
  description = "A map of custom scope names to their types (private or public)."
  value       = { for k, v in aws_vpc_ipam_scope.this : k => v.ipam_scope_type }
}

output "default_resource_discovery_association_id" {
  description = "The ID of the IPAM's default resource discovery association."
  value       = aws_vpc_ipam.this.default_resource_discovery_association_id
}

output "default_resource_discovery_id" {
  description = "The ID of the IPAM's default resource discovery."
  value       = aws_vpc_ipam.this.default_resource_discovery_id
}

output "delegated_admin_account_arn" {
  description = "The Organizations ARN for the delegated admin account, if created."
  value       = local.create_delegated_admin ? aws_vpc_ipam_organization_admin_account.this[0].arn : null
}

output "ipam_arn" {
  description = "The ARN of the IPAM."
  value       = aws_vpc_ipam.this.arn
}

output "ipam_id" {
  description = "The ID of the IPAM."
  value       = aws_vpc_ipam.this.id
}

output "private_default_scope_id" {
  description = "The ID of the IPAM's private default scope. Use this as the scope_id when creating private pools downstream."
  value       = aws_vpc_ipam.this.private_default_scope_id
}

output "public_default_scope_id" {
  description = "The ID of the IPAM's public default scope. Use this as the scope_id when creating public pools downstream."
  value       = aws_vpc_ipam.this.public_default_scope_id
}

output "resource_discovery_arn" {
  description = "The ARN of the IPAM resource discovery, if created."
  value       = local.create_resource_discovery ? aws_vpc_ipam_resource_discovery.this[0].arn : null
}

output "resource_discovery_association_id" {
  description = "The ID of the resource discovery association, if created."
  value       = local.create_resource_discovery ? aws_vpc_ipam_resource_discovery_association.this[0].id : null
}

output "resource_discovery_id" {
  description = "The ID of the IPAM resource discovery, if created."
  value       = local.create_resource_discovery ? aws_vpc_ipam_resource_discovery.this[0].id : null
}

output "scope_count" {
  description = "The number of scopes in the IPAM (includes default private and public scopes)."
  value       = aws_vpc_ipam.this.scope_count
}
