output "internet_gateway_id" {
  value       = var.create_igw ? aws_internet_gateway.this[0].id : null
  description = "The ID of the Internet Gateway, if created."
}

output "vpc_cidr_block" {
  value       = aws_vpc.this.cidr_block
  description = "The CIDR block of the VPC."
}

output "vpc_id" {
  value       = aws_vpc.this.id
  description = "The ID of the VPC."
}


