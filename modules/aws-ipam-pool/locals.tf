locals {
  tags = merge(
    {
      Name = var.name
    },
    var.tags
  )
}
