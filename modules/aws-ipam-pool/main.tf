################################################################################
# IPAM Pool
#
# Note: The source_resource block (for resource planning pools that track
# usage of an existing VPC's CIDR space) is not yet exposed by this module.
# Add it when resource planning pool support is needed.
################################################################################

resource "aws_vpc_ipam_pool" "this" {
  address_family                    = var.address_family
  allocation_default_netmask_length = var.allocation_default_netmask_length
  allocation_max_netmask_length     = var.allocation_max_netmask_length
  allocation_min_netmask_length     = var.allocation_min_netmask_length
  allocation_resource_tags          = var.allocation_resource_tags
  auto_import                       = var.auto_import
  aws_service                       = var.aws_service
  cascade                           = var.cascade_delete
  description                       = var.description
  ipam_scope_id                     = var.ipam_scope_id
  locale                            = var.locale
  public_ip_source                  = var.public_ip_source
  publicly_advertisable             = var.publicly_advertisable
  source_ipam_pool_id               = var.source_ipam_pool_id

  tags = local.tags

  lifecycle {
    precondition {
      condition     = var.publicly_advertisable == false || var.address_family == "ipv6"
      error_message = "publicly_advertisable is only valid for IPv6 pools. Set address_family to 'ipv6' or set publicly_advertisable to false."
    }
    precondition {
      condition     = var.public_ip_source == null || var.address_family == "ipv4"
      error_message = "public_ip_source is only valid for IPv4 pools in the public scope."
    }
    precondition {
      condition     = var.allocation_min_netmask_length == null || var.allocation_max_netmask_length == null || var.allocation_min_netmask_length <= var.allocation_max_netmask_length
      error_message = "allocation_min_netmask_length must be less than or equal to allocation_max_netmask_length."
    }
    precondition {
      condition = (
        var.allocation_default_netmask_length == null ||
        (
          (var.allocation_min_netmask_length == null || var.allocation_default_netmask_length >= var.allocation_min_netmask_length) &&
          (var.allocation_max_netmask_length == null || var.allocation_default_netmask_length <= var.allocation_max_netmask_length)
        )
      )
      error_message = "allocation_default_netmask_length must be between allocation_min_netmask_length and allocation_max_netmask_length (inclusive)."
    }
    precondition {
      condition = (
        var.address_family == "ipv6" ||
        alltrue([
          var.allocation_min_netmask_length == null || var.allocation_min_netmask_length <= 32,
          var.allocation_max_netmask_length == null || var.allocation_max_netmask_length <= 32,
          var.allocation_default_netmask_length == null || var.allocation_default_netmask_length <= 32,
          alltrue([for c in values(var.cidrs) : c.netmask_length == null || c.netmask_length <= 32]),
        ])
      )
      error_message = "For IPv4 pools, all netmask lengths (allocation_min, allocation_max, allocation_default, and cidrs[*].netmask_length) must be between 0 and 32."
    }
    precondition {
      condition = alltrue([
        for c in values(var.cidrs) : c.cidr == null || (
          var.address_family == "ipv4" ? !can(regex(":", c.cidr)) : can(regex(":", c.cidr))
        )
      ])
      error_message = "Each explicit CIDR must match the pool's address_family. IPv4 pools require IPv4 CIDRs (e.g. 10.0.0.0/8); IPv6 pools require IPv6 CIDRs (e.g. 2001:db8::/32)."
    }
    precondition {
      condition     = var.source_ipam_pool_id == null || var.locale != null
      error_message = "locale is required for child pools (when source_ipam_pool_id is set). Set locale to the AWS region where allocations from this pool will be used."
    }
  }
}

################################################################################
# IPAM Pool CIDRs
#
# Note: The cidr_authorization_context block (message + signature for BYOIP
# ownership verification) is not yet exposed by this module. Add it when
# Bring Your Own IP (BYOIP) pool support is needed.
################################################################################

resource "aws_vpc_ipam_pool_cidr" "this" {
  for_each = var.cidrs

  ipam_pool_id   = aws_vpc_ipam_pool.this.id
  cidr           = each.value.cidr
  netmask_length = each.value.netmask_length
}
