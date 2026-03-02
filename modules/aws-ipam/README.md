# AWS IPAM Module

Creates an AWS VPC IP Address Manager (IPAM) instance with optional custom scopes, AWS Organizations delegated admin, and resource discovery. IPAM centralizes IP address planning, tracking, and monitoring across your AWS accounts and regions. This module manages the IPAM instance and its supporting resources; pool creation is handled by a separate `aws-ipam-pool` module downstream.

## Usage

### Minimal (free tier, single region)

```hcl
module "ipam" {
  source = "../../modules/aws-ipam"

  # Required
  name              = "my-ipam"
  operating_regions = ["us-east-1"]
}
```

This creates a free-tier IPAM instance in a single region with default private and public scopes. No custom scopes, Organizations delegation, or resource discovery.

### With custom scopes

```hcl
module "ipam" {
  source = "../../modules/aws-ipam"

  # Required
  name              = "network-ipam"
  operating_regions = ["us-east-1", "us-west-2"]

  # Custom scopes for organizational boundaries
  custom_scopes = {
    production  = "Production workloads - strict allocation controls"
    development = "Development and sandbox environments"
  }

  description = "Multi-region IPAM for network team"

  tags = {
    Environment = "shared"
    Team        = "platform"
  }
}
```

### Advanced tier with Organizations delegation

```hcl
module "ipam" {
  source = "../../modules/aws-ipam"

  # Required
  name              = "org-ipam"
  operating_regions = ["us-east-1", "eu-west-1"]

  # Advanced tier (required for Organizations integration)
  tier = "advanced"

  # Delegate IPAM administration to a networking account
  delegated_admin_account_id = "123456789012"

  description = "Organization-wide IPAM managed by networking account"

  tags = {
    ManagedBy = "platform-team"
  }
}
```

### Advanced tier with resource discovery

```hcl
module "ipam" {
  source = "../../modules/aws-ipam"

  # Required
  name              = "discovery-ipam"
  operating_regions = ["us-east-1", "us-west-2", "eu-west-1"]

  # Advanced tier (required for resource discovery)
  tier = "advanced"

  # Enable resource discovery across regions
  resource_discovery_enabled     = true
  resource_discovery_description = "Discover existing VPCs and subnets across all regions"

  # Optionally limit discovery to a subset of operating regions
  # resource_discovery_operating_regions = ["us-east-1", "us-west-2"]
}
```

### Full configuration (all features enabled)

```hcl
module "ipam" {
  source = "../../modules/aws-ipam"

  # Required
  name              = "enterprise-ipam"
  operating_regions = ["us-east-1", "us-west-2", "eu-west-1"]

  # Advanced tier
  tier        = "advanced"
  description = "Enterprise IPAM with full feature set"

  # Organizations delegation
  delegated_admin_account_id = "123456789012"

  # Resource discovery
  resource_discovery_enabled              = true
  resource_discovery_description          = "Cross-account IP address discovery"
  resource_discovery_operating_regions    = ["us-east-1", "us-west-2"]

  # Private GUA (IPv6)
  enable_private_gua = true

  # Cascade delete for non-production (be careful in production)
  cascade_delete = false

  # Custom scopes
  custom_scopes = {
    production  = "Production environment IP space"
    staging     = "Staging and pre-production IP space"
    development = "Development and sandbox IP space"
  }

  tags = {
    Environment = "shared"
    Team        = "platform"
    CostCenter  = "networking"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | ~> 1.9 |
| aws | ~> 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cascade_delete | Enables you to quickly delete an IPAM, private scopes, pools in private scopes, and any allocations in the pools. When true, IPAM deletion cascades to all child resources. | `bool` | `false` | no |
| custom_scopes | A map of custom IPAM scopes to create. Keys are scope names, values are descriptions. Note: IPAM automatically creates a default private and public scope; custom scopes provide additional organizational boundaries. | `map(string)` | `{}` | no |
| delegated_admin_account_id | The AWS account ID to delegate as the IPAM administrator in AWS Organizations. When set, creates an aws_vpc_ipam_organization_admin_account resource. Leave null to skip Organizations delegation. | `string` | `null` | no |
| description | A description for the IPAM instance. | `string` | `""` | no |
| enable_private_gua | Whether to enable using your own GUA (Global Unicast Address) ranges as private IPv6 addresses. Only applicable when tier is 'advanced'. | `bool` | `false` | no |
| name | The name for the IPAM instance and related resources. Used in tags and resource naming. | `string` | n/a | yes |
| operating_regions | A list of AWS region names where IPAM will manage IP addresses. Must include the region where the provider is configured. At least one region is required. | `list(string)` | n/a | yes |
| resource_discovery_description | A description for the IPAM resource discovery. Only used when resource_discovery_enabled is true. | `string` | `""` | no |
| resource_discovery_enabled | Whether to create an IPAM resource discovery and associate it with the IPAM instance. Resource discovery enables cross-organization IP address monitoring. | `bool` | `false` | no |
| resource_discovery_operating_regions | A list of AWS region names for the resource discovery. Must include the provider region. When empty and resource_discovery_enabled is true, falls back to the IPAM operating_regions. | `list(string)` | `[]` | no |
| tags | A map of tags to apply to all resources created by this module. | `map(string)` | `{}` | no |
| tier | The IPAM tier. 'free' provides basic IPAM functionality at no cost. 'advanced' enables features like resource discovery, Organizations integration, and more. Defaults to 'free' for cost safety. | `string` | `"free"` | no |

## Outputs

| Name | Description |
|------|-------------|
| custom_scope_arns | A map of custom scope names to their ARNs. |
| custom_scope_ids | A map of custom scope names to their IDs. |
| custom_scope_types | A map of custom scope names to their types (private or public). |
| default_resource_discovery_association_id | The ID of the IPAM's default resource discovery association. |
| default_resource_discovery_id | The ID of the IPAM's default resource discovery. |
| delegated_admin_account_arn | The Organizations ARN for the delegated admin account, if created. |
| ipam_arn | The ARN of the IPAM. |
| ipam_id | The ID of the IPAM. |
| private_default_scope_id | The ID of the IPAM's private default scope. Use this as the scope_id when creating private pools downstream. |
| public_default_scope_id | The ID of the IPAM's public default scope. Use this as the scope_id when creating public pools downstream. |
| resource_discovery_arn | The ARN of the IPAM resource discovery, if created. |
| resource_discovery_association_id | The ID of the resource discovery association, if created. |
| resource_discovery_id | The ID of the IPAM resource discovery, if created. |
| scope_count | The number of scopes in the IPAM (includes default private and public scopes). |

## Resources Created

| Name | Type | Condition |
|------|------|-----------|
| aws_vpc_ipam.this | Resource | Always |
| aws_vpc_ipam_scope.this | Resource | `custom_scopes` is non-empty |
| aws_vpc_ipam_organization_admin_account.this | Resource | `delegated_admin_account_id` is set |
| aws_vpc_ipam_resource_discovery.this | Resource | `resource_discovery_enabled = true` |
| aws_vpc_ipam_resource_discovery_association.this | Resource | `resource_discovery_enabled = true` |

## Notes

### Tier requirements for advanced features

Three features require `tier = "advanced"` and will fail at plan time if you attempt to use them on the free tier:

| Feature | Variable | Precondition |
|---------|----------|--------------|
| Private GUA (IPv6) | `enable_private_gua = true` | Requires `tier = "advanced"` |
| Organizations delegation | `delegated_admin_account_id` set | Requires `tier = "advanced"` |
| Resource discovery | `resource_discovery_enabled = true` | Requires `tier = "advanced"` |

The module defaults to `tier = "free"` for cost safety. The advanced tier incurs per-active-IP-address charges.

### Default scopes are auto-created

Every IPAM instance automatically gets a private default scope and a public default scope. You do not need to create these; the module exposes their IDs via `private_default_scope_id` and `public_default_scope_id`. Custom scopes created via the `custom_scopes` variable are in addition to these defaults.

### Resource discovery region fallback

When `resource_discovery_enabled = true` and `resource_discovery_operating_regions` is left empty (the default), the resource discovery inherits the IPAM's `operating_regions`. Set `resource_discovery_operating_regions` explicitly only if you need discovery in a different subset of regions than the IPAM operates in.

### Cascade delete

Setting `cascade_delete = true` allows Terraform to destroy the IPAM even when pools and allocations exist under it. This is useful in development and testing environments but dangerous in production. The default is `false`, which requires you to manually clean up child resources before destroying the IPAM.

### Name validation

The `name` variable accepts 1-64 characters, alphanumeric and hyphens only. It is used in `Name` tags across all resources, with suffixes appended for sub-resources (e.g., `my-ipam-resource-discovery`).

### Custom scope descriptions required

Each entry in `custom_scopes` must have a non-empty description. The validation enforces this because scopes exist for organizational clarity, and an undocumented scope defeats the purpose.

### Organizations delegation prerequisites

Using `delegated_admin_account_id` requires that:
- AWS Organizations is enabled in the management account.
- The Terraform apply runs from the management account (or an account with `organizations:RegisterDelegatedAdministrator` permissions).
- The target account ID is a member of the organization.

### OU exclusion not yet exposed

The `aws_vpc_ipam_resource_discovery` resource supports `organizational_unit_exclusion` blocks to exclude specific OUs from IP management. This is not yet exposed by this module. Add it when multi-account OU filtering is needed.

### Phase 2: aws-ipam-pool module

This module creates the IPAM instance and its supporting infrastructure. Pool creation (CIDR provisioning, allocation rules, nested pool hierarchies) is handled by a separate `aws-ipam-pool` module. Use `ipam_id`, `private_default_scope_id`, or `custom_scope_ids` from this module's outputs as inputs to the pool module.

### Tag merging

The module sets a `Name` tag from the `name` variable on all resources. Sub-resources get descriptive suffixes (e.g., `-resource-discovery`, `-discovery-association`). Tags passed via `tags` are merged with these defaults.
