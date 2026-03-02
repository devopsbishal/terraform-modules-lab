variable "address_family" {
  description = "The IP protocol assigned to this pool. Determines whether the pool manages IPv4 or IPv6 addresses."
  type        = string
  default     = "ipv4"
  validation {
    condition     = contains(["ipv4", "ipv6"], var.address_family)
    error_message = "The address_family must be either 'ipv4' or 'ipv6'."
  }
  nullable = false
}

variable "allocation_default_netmask_length" {
  description = "The default netmask length for allocations added to this pool. When a VPC requests a CIDR from this pool without specifying a size, this value is used. For IPv4, /24 provides 256 addresses per VPC (a sensible starting point)."
  type        = number
  default     = null
  validation {
    condition     = var.allocation_default_netmask_length == null || (var.allocation_default_netmask_length >= 0 && var.allocation_default_netmask_length <= 128)
    error_message = "The allocation_default_netmask_length must be between 0 and 128."
  }
}

variable "allocation_max_netmask_length" {
  description = "The maximum netmask length that can be requested from this pool. Acts as a guardrail to prevent overly small allocations (e.g., /32 for a single IP). For IPv4, /28 limits the smallest allocation to 16 addresses."
  type        = number
  default     = null
  validation {
    condition     = var.allocation_max_netmask_length == null || (var.allocation_max_netmask_length >= 0 && var.allocation_max_netmask_length <= 128)
    error_message = "The allocation_max_netmask_length must be between 0 and 128."
  }
}

variable "allocation_min_netmask_length" {
  description = "The minimum netmask length that can be requested from this pool. Acts as a guardrail to prevent overly large allocations that could exhaust pool space. For IPv4, /16 limits the largest allocation to 65536 addresses."
  type        = number
  default     = null
  validation {
    condition     = var.allocation_min_netmask_length == null || (var.allocation_min_netmask_length >= 0 && var.allocation_min_netmask_length <= 128)
    error_message = "The allocation_min_netmask_length must be between 0 and 128."
  }
}

variable "allocation_resource_tags" {
  description = "A map of tags that resources must have to allocate CIDRs from this pool. Provides tag-based access control: only resources with ALL of these tags can use this pool. Leave empty to allow any resource."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "auto_import" {
  description = "Whether IPAM will automatically import any VPCs in your scope that fall within the CIDR range of this pool. Defaults to false for explicit control over pool membership."
  type        = bool
  default     = false
  nullable    = false
}

variable "aws_service" {
  description = "Limits which AWS service can use this pool. Currently only 'ec2' is supported. Set to null to allow any service."
  type        = string
  default     = null
  validation {
    condition     = var.aws_service == null || var.aws_service == "ec2"
    error_message = "The aws_service must be 'ec2' or null. Currently only 'ec2' is supported by AWS."
  }
}

variable "cascade_delete" {
  description = "Enables you to quickly delete this IPAM pool and all resources within it, including CIDRs and allocations. Defaults to false for safety."
  type        = bool
  default     = false
  nullable    = false
}

variable "cidrs" {
  description = "A map of CIDRs to provision into this pool. Keys are stable identifiers used as for_each keys (e.g. 'prod-cidr', 'dev-slash-16'). Each value specifies either 'cidr' (explicit CIDR block) or 'netmask_length' (allocate from parent pool by size), but not both. When the pool has a source_ipam_pool_id, use netmask_length to let the parent pool assign a CIDR automatically."
  type = map(object({
    cidr           = optional(string)
    netmask_length = optional(number)
  }))
  default = {}
  validation {
    condition     = alltrue([for c in values(var.cidrs) : (c.cidr != null) != (c.netmask_length != null)])
    error_message = "Each CIDR entry must specify exactly one of 'cidr' or 'netmask_length', not both and not neither."
  }
  validation {
    condition     = alltrue([for c in values(var.cidrs) : c.cidr == null || can(cidrhost(c.cidr, 0))])
    error_message = "Each 'cidr' value must be a valid CIDR notation (e.g. 10.0.0.0/16, 2001:db8::/32)."
  }
  validation {
    condition     = alltrue([for c in values(var.cidrs) : c.netmask_length == null || (c.netmask_length >= 0 && c.netmask_length <= 128)])
    error_message = "Each 'netmask_length' must be between 0 and 128."
  }
  nullable = false
}

variable "description" {
  description = "A description for the IPAM pool."
  type        = string
  default     = ""
  validation {
    condition     = length(var.description) <= 256
    error_message = "The description must be 256 characters or fewer."
  }
  nullable = false
}

variable "ipam_scope_id" {
  description = "The ID of the IPAM scope in which to create this pool. Use the private_default_scope_id or public_default_scope_id output from the aws-ipam module, or a custom scope ID."
  type        = string
  validation {
    condition     = can(regex("^ipam-scope-[0-9a-f]+$", var.ipam_scope_id))
    error_message = "The ipam_scope_id must be a valid IPAM scope ID (e.g. ipam-scope-0123456789abcdef0)."
  }
  nullable = false
}

variable "locale" {
  description = "The AWS region where allocations from this pool are available. Required for regional (child) pools. Set to null for top-level pools that span all IPAM operating regions."
  type        = string
  default     = null
  validation {
    condition     = var.locale == null || can(regex("^(us-gov-[a-z]+-\\d|[a-z]{2}-[a-z]+-\\d)$", var.locale))
    error_message = "The locale must be a valid AWS region name (e.g. us-east-1, eu-west-2, us-gov-west-1)."
  }
}

variable "name" {
  description = "The name for the IPAM pool and related resources. Used in tags and resource naming."
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

variable "public_ip_source" {
  description = "The IP address source for pools in the public scope. Only relevant for public scope pools. Valid values: 'byoip', 'amazon'. Defaults to null (not set) since most pools are private."
  type        = string
  default     = null
  validation {
    condition     = var.public_ip_source == null || contains(["byoip", "amazon"], var.public_ip_source)
    error_message = "The public_ip_source must be 'byoip', 'amazon', or null."
  }
}

variable "publicly_advertisable" {
  description = "Whether the IPv6 CIDR block is publicly advertisable over the internet. Only relevant for IPv6 pools with BYOIP. Defaults to false."
  type        = bool
  default     = false
  nullable    = false
}

variable "source_ipam_pool_id" {
  description = "The ID of the parent IPAM pool for creating a nested (child) pool. Set to null for top-level pools that provision CIDRs directly."
  type        = string
  default     = null
  validation {
    condition     = var.source_ipam_pool_id == null || can(regex("^ipam-pool-[0-9a-f]+$", var.source_ipam_pool_id))
    error_message = "The source_ipam_pool_id must be a valid IPAM pool ID (e.g. ipam-pool-0123456789abcdef0)."
  }
}

variable "tags" {
  description = "A map of tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
  nullable    = false
}
