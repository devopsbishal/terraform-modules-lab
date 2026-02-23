variable "availability_zone" {
  description = "The AZ where the subnet will be created."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9][a-z]$", var.availability_zone))
    error_message = "availability_zone must match a valid AZ pattern (e.g., 'us-east-1a')."
  }
}

variable "cidr_block" {
  description = "The IPv4 CIDR block for the subnet (e.g., '10.0.1.0/24'). Must be a subset of the VPC's CIDR block."
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "cidr_block must be a valid CIDR notation (e.g., '10.0.1.0/24'). This defines the IP address range for the subnet and must fall within your VPC's CIDR block."
  }
}

variable "map_public_ip_on_launch" {
  description = "Whether to assign a public IP address to instances launched in this subnet."
  type        = bool
  default     = false
}

variable "name" {
  description = "The name of the subnet."
  type        = string
  default     = "terraform-subnet"

  validation {
    condition     = length(var.name) > 0
    error_message = "name must not be empty."
  }
}

variable "tags" {
  description = "A map of tags to assign to the subnet."
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "The ID of the VPC in which to create the subnet."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "The vpc_id must match the format vpc- followed by hexadecimal characters."
  }
}
