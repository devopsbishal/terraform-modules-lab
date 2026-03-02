locals {
  create_delegated_admin    = var.delegated_admin_account_id != null
  create_resource_discovery = var.resource_discovery_enabled

  resource_discovery_operating_regions = length(var.resource_discovery_operating_regions) > 0 ? var.resource_discovery_operating_regions : var.operating_regions

  tags = merge(
    {
      Name = var.name
    },
    var.tags
  )
}
