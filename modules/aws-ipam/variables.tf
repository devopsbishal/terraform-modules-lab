variable "cascade_delete" {
  description = "Enables you to quickly delete an IPAM, private scopes, pools in private scopes, and any allocations in the pools. When true, IPAM deletion cascades to all child resources."
  type        = bool
  default     = false
  nullable    = false
}

variable "custom_scopes" {
  description = "A map of custom IPAM scopes to create. Keys are scope names, values are descriptions. Note: IPAM automatically creates a default private and public scope; custom scopes provide additional organizational boundaries."
  type        = map(string)
  default     = {}
  validation {
    condition     = alltrue([for k, v in var.custom_scopes : length(trimspace(v)) > 0])
    error_message = "Each custom scope must have a non-empty description. Custom scopes exist for organizational clarity — a description is required."
  }
}

variable "delegated_admin_account_id" {
  description = "The AWS account ID to delegate as the IPAM administrator in AWS Organizations. When set, creates an aws_vpc_ipam_organization_admin_account resource. Leave null to skip Organizations delegation."
  type        = string
  default     = null
  validation {
    condition     = var.delegated_admin_account_id == null || can(regex("^\\d{12}$", var.delegated_admin_account_id))
    error_message = "The delegated_admin_account_id must be a 12-digit AWS account ID."
  }
}

variable "description" {
  description = "A description for the IPAM instance."
  type        = string
  default     = ""
  validation {
    condition     = length(var.description) <= 256
    error_message = "The description must be 256 characters or fewer."
  }
  nullable = false
}

variable "enable_private_gua" {
  description = "Whether to enable using your own GUA (Global Unicast Address) ranges as private IPv6 addresses. Only applicable when tier is 'advanced'."
  type        = bool
  default     = false
  nullable    = false
}

## metered_account — deferred until provider version is upgraded to ~> 6.11
## The metered_account argument (ipam-owner vs resource-owner billing) was added
## in AWS provider v6.11.0. This module currently pins to ~> 5.0. Add this
## variable and wire it to aws_vpc_ipam.this when the provider constraint is bumped.

variable "name" {
  description = "The name for the IPAM instance and related resources. Used in tags and resource naming."
  type        = string
  validation {
    condition     = length(var.name) >= 1 && length(var.name) <= 64
    error_message = "The name must be between 1 and 64 characters."
  }
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.name))
    error_message = "The name may only contain alphanumeric characters and hyphens."
  }
  nullable = false
}

variable "operating_regions" {
  description = "A list of AWS region names where IPAM will manage IP addresses. Must include the region where the provider is configured. At least one region is required."
  type        = list(string)
  validation {
    condition     = length(var.operating_regions) >= 1
    error_message = "At least one operating region must be specified."
  }
  validation {
    condition     = alltrue([for r in var.operating_regions : can(regex("^(us-gov-[a-z]+-\\d|[a-z]{2}-[a-z]+-\\d)$", r))])
    error_message = "Each operating region must be a valid AWS region name (e.g. us-east-1, eu-west-2, us-gov-west-1)."
  }
  nullable = false
}

variable "resource_discovery_description" {
  description = "A description for the IPAM resource discovery. Only used when resource_discovery_enabled is true."
  type        = string
  default     = ""
  validation {
    condition     = length(var.resource_discovery_description) <= 256
    error_message = "The resource_discovery_description must be 256 characters or fewer."
  }
}

variable "resource_discovery_enabled" {
  description = "Whether to create an IPAM resource discovery and associate it with the IPAM instance. Resource discovery enables cross-organization IP address monitoring."
  type        = bool
  default     = false
  nullable    = false
}

variable "resource_discovery_operating_regions" {
  description = "A list of AWS region names for the resource discovery. Must include the provider region. When empty and resource_discovery_enabled is true, falls back to the IPAM operating_regions."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for r in var.resource_discovery_operating_regions : can(regex("^(us-gov-[a-z]+-\\d|[a-z]{2}-[a-z]+-\\d)$", r))])
    error_message = "Each operating region must be a valid AWS region name (e.g. us-east-1, eu-west-2, us-gov-west-1)."
  }
}

variable "tags" {
  description = "A map of tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}

variable "tier" {
  description = "The IPAM tier. 'free' provides basic IPAM functionality at no cost. 'advanced' enables features like resource discovery, Organizations integration, and more. Defaults to 'free' for cost safety."
  type        = string
  default     = "free"
  validation {
    condition     = contains(["free", "advanced"], var.tier)
    error_message = "The tier must be either 'free' or 'advanced'."
  }
  nullable = false
}
