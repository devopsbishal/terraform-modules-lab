output "pool_arn" {
  description = "The ARN of the IPAM pool."
  value       = aws_vpc_ipam_pool.this.arn
}

output "pool_cidr_ids" {
  description = "A map of CIDR keys to their IPAM pool CIDR resource IDs."
  value       = { for k, v in aws_vpc_ipam_pool_cidr.this : k => v.ipam_pool_cidr_id }
}

output "pool_cidrs" {
  description = "A map of user-provided CIDR keys to the provisioned CIDR blocks. For netmask_length allocations, the value is the CIDR assigned by IPAM."
  value       = { for k, v in aws_vpc_ipam_pool_cidr.this : k => v.cidr }
}

output "pool_id" {
  description = "The ID of the IPAM pool. Waits for all pool CIDRs to be provisioned before returning, ensuring the pool is ready for allocations."
  value       = aws_vpc_ipam_pool.this.id
  depends_on  = [aws_vpc_ipam_pool_cidr.this]
}

output "pool_state" {
  description = "The state of the IPAM pool (e.g. create-complete, modify-complete)."
  value       = aws_vpc_ipam_pool.this.state
}
