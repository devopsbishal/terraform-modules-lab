################################################################################
# IPAM
################################################################################

resource "aws_vpc_ipam" "this" {
  cascade            = var.cascade_delete
  description        = var.description
  enable_private_gua = var.enable_private_gua
  tier               = var.tier

  dynamic "operating_regions" {
    for_each = var.operating_regions
    content {
      region_name = operating_regions.value
    }
  }

  tags = local.tags

  lifecycle {
    precondition {
      condition     = var.enable_private_gua == false || var.tier == "advanced"
      error_message = "enable_private_gua requires tier = 'advanced'. The free tier does not support private GUA addresses."
    }
  }
}

################################################################################
# Custom Scopes
################################################################################

resource "aws_vpc_ipam_scope" "this" {
  for_each = var.custom_scopes

  description = each.value
  ipam_id     = aws_vpc_ipam.this.id

  tags = merge(
    local.tags,
    {
      Name = "${var.name}-${each.key}"
    }
  )
}

################################################################################
# Organizations Delegated Admin
################################################################################

resource "aws_vpc_ipam_organization_admin_account" "this" {
  count = local.create_delegated_admin ? 1 : 0

  delegated_admin_account_id = var.delegated_admin_account_id

  lifecycle {
    precondition {
      condition     = var.tier == "advanced"
      error_message = "Organizations delegated admin requires tier = 'advanced'. The free tier does not support AWS Organizations integration."
    }
  }
}

################################################################################
# Resource Discovery
# Note: aws_vpc_ipam_resource_discovery also supports organizational_unit_exclusion
# blocks to exclude specific OUs from IP management. This is not yet exposed by
# this module — add it when multi-account OU filtering is needed.
################################################################################

resource "aws_vpc_ipam_resource_discovery" "this" {
  count = local.create_resource_discovery ? 1 : 0

  description = var.resource_discovery_description

  dynamic "operating_regions" {
    for_each = local.resource_discovery_operating_regions
    content {
      region_name = operating_regions.value
    }
  }

  tags = merge(
    local.tags,
    {
      Name = "${var.name}-resource-discovery"
    }
  )

  lifecycle {
    precondition {
      condition     = var.tier == "advanced"
      error_message = "Resource discovery requires tier = 'advanced'. The free tier does not support resource discovery."
    }
  }
}

################################################################################
# Resource Discovery Association
################################################################################

resource "aws_vpc_ipam_resource_discovery_association" "this" {
  count = local.create_resource_discovery ? 1 : 0

  ipam_id                    = aws_vpc_ipam.this.id
  ipam_resource_discovery_id = aws_vpc_ipam_resource_discovery.this[0].id

  tags = merge(
    local.tags,
    {
      Name = "${var.name}-discovery-association"
    }
  )
}
