variable "aws_profile" {
  description = "The AWS CLI profile to use for authentication. Maps to the provider's 'profile' argument."
  type        = string
  default     = "default"
  nullable    = false
}

variable "aws_region" {
  description = "The AWS region to deploy into. Used for the provider, IPAM operating region, and pool locale."
  type        = string
  default     = "us-west-2"
  validation {
    condition     = can(regex("^(us-gov-[a-z]+-\\d|[a-z]{2}-[a-z]+-\\d)$", var.aws_region))
    error_message = "Must be a valid AWS region name (e.g. us-east-1, eu-west-2)."
  }
  nullable = false
}

variable "environment" {
  description = "The environment name (e.g. dev, staging, production). Used in resource naming and the pool hierarchy."
  type        = string
  default     = "production"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,19}$", var.environment))
    error_message = "The environment must be 1-20 lowercase alphanumeric characters or hyphens, starting with a letter."
  }
  nullable = false
}

variable "flow_log_enabled" {
  description = "Whether to enable VPC Flow Logs. Disabled by default in this composition since IPAM exploration does not require network traffic visibility."
  type        = bool
  default     = false
  nullable    = false
}

variable "ipam_tier" {
  description = "The IPAM tier. 'free' provides basic functionality at no cost. 'advanced' enables resource discovery and Organizations integration but incurs hourly charges."
  type        = string
  default     = "advanced"
  validation {
    condition     = contains(["free", "advanced"], var.ipam_tier)
    error_message = "The ipam_tier must be either 'free' or 'advanced'."
  }
  nullable = false
}

variable "project_name" {
  description = "A short project identifier used as a prefix in resource names (e.g. 'lab', 'platform'). Keeps names unique when multiple compositions share an account."
  type        = string
  default     = "lab"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,11}$", var.project_name))
    error_message = "The project_name must be 1-12 lowercase alphanumeric characters or hyphens, starting with a letter."
  }
  nullable = false
}

variable "tags" {
  description = "Additional tags to merge with the default tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "top_level_cidr" {
  description = "The RFC 1918 CIDR block provisioned into the top-level pool. This is the supernet from which all child pools and VPCs are carved."
  type        = string
  default     = "10.0.0.0/8"
  validation {
    condition     = can(cidrhost(var.top_level_cidr, 0))
    error_message = "The top_level_cidr must be a valid CIDR notation (e.g. 10.0.0.0/8)."
  }
  nullable = false
}

variable "vpc_netmask_length" {
  description = "The netmask length for the VPC CIDR allocated from the environment pool. /20 provides 4,096 addresses -- enough for exploration without wasting pool space."
  type        = number
  default     = 20
  validation {
    condition     = var.vpc_netmask_length >= 16 && var.vpc_netmask_length <= 28
    error_message = "The vpc_netmask_length must be between 16 and 28."
  }
  nullable = false
}
