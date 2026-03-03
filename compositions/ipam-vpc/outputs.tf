################################################################################
# IPAM
################################################################################

output "ipam_id" {
  description = "The ID of the IPAM instance."
  value       = module.ipam.ipam_id
}

output "ipam_arn" {
  description = "The ARN of the IPAM instance."
  value       = module.ipam.ipam_arn
}

################################################################################
# Pool Hierarchy
################################################################################

output "top_level_pool_id" {
  description = "The ID of the top-level IPAM pool."
  value       = module.top_level_pool.pool_id
}

output "top_level_pool_cidrs" {
  description = "The CIDRs provisioned in the top-level pool."
  value       = module.top_level_pool.pool_cidrs
}

output "regional_pool_id" {
  description = "The ID of the regional IPAM pool."
  value       = module.regional_pool.pool_id
}

output "regional_pool_cidrs" {
  description = "The CIDRs assigned to the regional pool."
  value       = module.regional_pool.pool_cidrs
}

output "environment_pool_id" {
  description = "The ID of the environment IPAM pool."
  value       = module.environment_pool.pool_id
}

output "environment_pool_cidrs" {
  description = "The CIDRs assigned to the environment pool."
  value       = module.environment_pool.pool_cidrs
}

################################################################################
# VPC
################################################################################

output "vpc_id" {
  description = "The ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_arn" {
  description = "The ARN of the VPC."
  value       = module.vpc.vpc_arn
}

output "vpc_cidr_block" {
  description = "The IPv4 CIDR block assigned to the VPC by IPAM."
  value       = module.vpc.vpc_cidr_block
}

################################################################################
# Summary
################################################################################

output "summary" {
  description = "A human-readable summary of the deployed IPAM hierarchy and VPC."
  value       = <<-EOT
    IPAM Hierarchy
    ==============
    IPAM:             ${module.ipam.ipam_id} (${var.ipam_tier})
    Top-level pool:   ${module.top_level_pool.pool_id} -> ${join(", ", values(module.top_level_pool.pool_cidrs))}
    Regional pool:    ${module.regional_pool.pool_id} -> ${join(", ", values(module.regional_pool.pool_cidrs))}
    Environment pool: ${module.environment_pool.pool_id} -> ${join(", ", values(module.environment_pool.pool_cidrs))}

    VPC
    ===
    VPC:              ${module.vpc.vpc_id} -> ${module.vpc.vpc_cidr_block}
    Region:           ${var.aws_region}
    Environment:      ${var.environment}
  EOT
}
