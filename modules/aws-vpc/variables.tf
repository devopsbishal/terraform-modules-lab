variable "assign_generated_ipv6_cidr_block" {
  description = "Request an Amazon-provided IPv6 /56 CIDR block with a /56 prefix length."
  type        = bool
  default     = false
}

variable "cidr_block" {
  description = "The IPv4 CIDR block for the VPC (e.g. 10.0.0.0/16)."
  type        = string
  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "The cidr_block value must be a valid IPv4 CIDR notation (e.g. 10.0.0.0/16)."
  }
  validation {
    condition     = can(tonumber(split("/", var.cidr_block)[1])) && tonumber(split("/", var.cidr_block)[1]) >= 16 && tonumber(split("/", var.cidr_block)[1]) <= 24
    error_message = "The CIDR block prefix length must be between /16 and /24."
  }
  nullable = false
}

variable "create_igw" {
  description = "Whether to create an Internet Gateway and attach it to the VPC."
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Whether to enable DNS hostnames in the VPC. Required for private hosted zones and EKS."
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Whether to enable DNS support in the VPC. Must be true for enable_dns_hostnames to work."
  type        = bool
  default     = true
}

variable "enable_network_address_usage_metrics" {
  description = "Whether to enable Network Address Usage (NAU) metrics for the VPC."
  type        = bool
  default     = false
}

variable "flow_log_cloudwatch_kms_key_id" {
  description = "The ARN of the KMS key to use for encrypting the CloudWatch Log Group for VPC flow logs. When null, CloudWatch default encryption is used."
  type        = string
  default     = null
}

variable "flow_log_cloudwatch_log_group_retention_in_days" {
  description = "Number of days to retain VPC flow log events in CloudWatch Logs."
  type        = number
  default     = 30
  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.flow_log_cloudwatch_log_group_retention_in_days)
    error_message = "The retention value must be one of the allowed CloudWatch Logs retention periods."
  }
}

variable "flow_log_destination_arn" {
  description = "The ARN of the destination for VPC flow logs (CloudWatch Log Group or S3 bucket). When flow_log_destination_type is cloud-watch-logs and this is null, a log group is created automatically."
  type        = string
  default     = null
}

variable "flow_log_destination_type" {
  description = "The type of destination for VPC flow logs. Valid values: cloud-watch-logs, s3."
  type        = string
  default     = "cloud-watch-logs"
  validation {
    condition     = contains(["cloud-watch-logs", "s3"], var.flow_log_destination_type)
    error_message = "The flow_log_destination_type must be either 'cloud-watch-logs' or 's3'."
  }
}

variable "flow_log_enabled" {
  description = "Whether to enable VPC Flow Logs for network traffic visibility."
  type        = bool
  default     = true
}

variable "flow_log_iam_role_arn" {
  description = "The ARN of an existing IAM role for VPC flow logs to use. Required when providing an external flow_log_destination_arn with cloud-watch-logs destination type. When null and destination is cloud-watch-logs with no external ARN, a role is created automatically."
  type        = string
  default     = null
}

variable "flow_log_max_aggregation_interval" {
  description = "The maximum interval of time (in seconds) during which flow log records are captured and aggregated."
  type        = number
  default     = 600
  validation {
    condition     = contains([60, 600], var.flow_log_max_aggregation_interval)
    error_message = "The max aggregation interval must be either 60 or 600 seconds."
  }
}

variable "flow_log_traffic_type" {
  description = "The type of traffic to capture in VPC flow logs. Valid values: ACCEPT, REJECT, ALL."
  type        = string
  default     = "ALL"
  validation {
    condition     = contains(["ACCEPT", "REJECT", "ALL"], var.flow_log_traffic_type)
    error_message = "The flow_log_traffic_type must be one of: ACCEPT, REJECT, ALL."
  }
}

variable "instance_tenancy" {
  description = "A tenancy option for instances launched into the VPC. Use 'dedicated' for compliance workloads requiring hardware isolation."
  type        = string
  default     = "default"
  validation {
    condition     = contains(["default", "dedicated"], var.instance_tenancy)
    error_message = "The instance_tenancy must be either 'default' or 'dedicated'."
  }
}

variable "manage_default_security_group" {
  description = "Whether to adopt and lock down the VPC's default security group by removing all ingress and egress rules."
  type        = bool
  default     = true
}

variable "name" {
  description = "The name for the VPC and related resources. Used in Name tags and resource naming."
  type        = string
  validation {
    condition     = length(var.name) >= 1 && length(var.name) <= 46
    error_message = "The name must be between 1 and 46 characters. The limit accounts for suffixes appended to derived resource names (e.g. IAM role name has a 64-character AWS limit)."
  }
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.name))
    error_message = "The name may only contain alphanumeric characters and hyphens."
  }
  nullable = false
}

variable "tags" {
  description = "A map of tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}
