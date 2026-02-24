locals {
  create_flow_log           = var.flow_log_enabled
  create_flow_log_log_group = local.create_flow_log && var.flow_log_destination_type == "cloud-watch-logs" && var.flow_log_destination_arn == null
  create_flow_log_iam_role  = local.create_flow_log_log_group

  tags = merge(
    {
      Name = var.name
    },
    var.tags
  )
}
