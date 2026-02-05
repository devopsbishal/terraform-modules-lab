variable "cidr_block" {
  description = "The CIDR block for the VPC."
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr_block, 0)) // Checks if the provided CIDR block is valid
    error_message = "The provided CIDR block is not valid."
  }

  validation {
    condition     = tonumber(split("/", var.cidr_block)[1]) >= 16 && tonumber(split("/", var.cidr_block)[1]) <= 24
    error_message = "The CIDR block must be between /16 and /24."
  }
}

variable "create_igw" {
  description = "A boolean flag to create or not create an Internet Gateway."
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "A boolean flag to enable/disable DNS hostnames in the VPC."
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "A boolean flag to enable/disable DNS support in the VPC."
  type        = bool
  default     = true
}

variable "name" {
  description = "The name of the VPC."
  type        = string
  default     = "terraform-vpc"
}

variable "tags" {
  description = "A map of tags to assign to the VPC."
  type        = map(string)
  default     = {}
}
