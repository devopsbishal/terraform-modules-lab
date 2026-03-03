################################################################################
# Provider
################################################################################

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Managed-By = "Terraform"
    }
  }
}

################################################################################
# IPAM Instance
################################################################################

module "ipam" {
  source = "../../modules/aws-ipam"

  name              = local.ipam_name
  operating_regions = [var.aws_region]
  cascade_delete    = true
  tier              = var.ipam_tier

  tags = local.tags
}

################################################################################
# Pool Hierarchy
#
# top-level (/8)  -->  regional (/10)  -->  environment (/14)  -->  VPC (/20)
#
# The top-level pool holds the RFC 1918 supernet. Regional and environment
# pools carve progressively smaller slices. cascade_delete = true on every
# pool so `terraform destroy` cleans up in one pass.
################################################################################

module "top_level_pool" {
  source = "../../modules/aws-ipam-pool"

  name           = local.top_pool_name
  ipam_scope_id  = module.ipam.private_default_scope_id
  cascade_delete = true
  cidrs = {
    main = { cidr = var.top_level_cidr, netmask_length = null }
  }

  tags = local.tags
}

module "regional_pool" {
  source = "../../modules/aws-ipam-pool"

  name                = local.region_pool
  ipam_scope_id       = module.ipam.private_default_scope_id
  source_ipam_pool_id = module.top_level_pool.pool_id
  locale              = var.aws_region
  cascade_delete      = true
  cidrs = {
    main = { netmask_length = local.regional_netmask }
  }

  tags = local.tags
}

module "environment_pool" {
  source = "../../modules/aws-ipam-pool"

  name                = local.env_pool_name
  ipam_scope_id       = module.ipam.private_default_scope_id
  source_ipam_pool_id = module.regional_pool.pool_id
  locale              = var.aws_region
  cascade_delete      = true
  cidrs = {
    main = { netmask_length = local.environment_netmask }
  }

  tags = local.tags
}

################################################################################
# VPC
################################################################################

module "vpc" {
  source = "../../modules/aws-vpc"

  name                = local.vpc_name
  ipv4_ipam_pool_id   = module.environment_pool.pool_id
  ipv4_netmask_length = var.vpc_netmask_length
  flow_log_enabled    = var.flow_log_enabled

  tags = local.tags
}
