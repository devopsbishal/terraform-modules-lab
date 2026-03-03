locals {
  # -----------------------------------------------------------------------
  # Naming: all resource names follow {project}-{purpose} or
  # {project}-{region_short}-{purpose} for regional resources.
  # -----------------------------------------------------------------------
  region_short = replace(var.aws_region, "/^([a-z]{2})-([a-z])[a-z]+-([0-9])$/", "$1$2$3")

  ipam_name     = "${var.project_name}-ipam"
  top_pool_name = "${var.project_name}-top-level"
  region_pool   = "${var.project_name}-${local.region_short}"
  env_pool_name = "${var.project_name}-${local.region_short}-${var.environment}"
  vpc_name      = "${var.project_name}-${var.environment}-vpc"

  # -----------------------------------------------------------------------
  # Pool sizing: each tier carves a progressively smaller slice.
  # top-level (/8) -> regional (/10) -> environment (/14) -> VPC (/20)
  # -----------------------------------------------------------------------
  regional_netmask    = 10
  environment_netmask = 14

  # -----------------------------------------------------------------------
  # Tags: baseline tags applied to every resource via both default_tags
  # (provider-level) and module-level tags.
  # -----------------------------------------------------------------------
  tags = merge(
    {
      Composition = "ipam-vpc"
      Environment = var.environment
      Project     = var.project_name
    },
    var.tags,
  )
}
