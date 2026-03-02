# AWS IPAM Pool Module

Creates an AWS VPC IPAM pool and provisions CIDRs into it. IPAM pools are containers for CIDR ranges that VPCs draw their IP addresses from. Pools can be arranged in hierarchies -- a top-level pool holds the aggregate CIDR space, and regional child pools carve out subsets for specific AWS regions. This module manages a single pool and its CIDRs; call it multiple times to build a pool hierarchy. It consumes outputs from the `aws-ipam` module (specifically `ipam_scope_id`).

## Usage

### Minimal top-level pool (single CIDR)

```hcl
module "top_level_pool" {
  source = "../../modules/aws-ipam-pool"

  # Required
  name          = "corp-ipv4-top"
  ipam_scope_id = module.ipam.private_default_scope_id

  # Provision a single CIDR into the pool
  cidrs = {
    rfc1918-10 = { cidr = "10.0.0.0/8", netmask_length = null }
  }
}
```

### Regional child pool (with source pool and locale)

```hcl
module "us_east_pool" {
  source = "../../modules/aws-ipam-pool"

  # Required
  name          = "us-east-1-pool"
  ipam_scope_id = module.ipam.private_default_scope_id

  # This is a child pool -- inherit CIDRs from the top-level pool
  source_ipam_pool_id = module.top_level_pool.pool_id
  locale              = "us-east-1"

  # Request a /16 from the parent by size, not by explicit CIDR
  cidrs = {
    primary = { cidr = null, netmask_length = 16 }
  }

  description = "Regional pool for us-east-1 workloads"
}
```

### Pool with allocation guardrails

```hcl
module "guardrailed_pool" {
  source = "../../modules/aws-ipam-pool"

  # Required
  name          = "prod-guardrailed"
  ipam_scope_id = module.ipam.private_default_scope_id

  source_ipam_pool_id = module.top_level_pool.pool_id
  locale              = "us-west-2"

  cidrs = {
    primary = { cidr = null, netmask_length = 16 }
  }

  # Guardrails: VPCs get /24 by default, can request /20 to /28
  allocation_default_netmask_length = 24
  allocation_min_netmask_length     = 20
  allocation_max_netmask_length     = 28

  # Only VPCs tagged Environment=production can allocate from this pool
  allocation_resource_tags = {
    Environment = "production"
  }
}
```

### Nested pool hierarchy (multiple module calls)

```hcl
# 1. Top-level pool: holds the aggregate CIDR space
module "top_pool" {
  source = "../../modules/aws-ipam-pool"

  name          = "corp-top"
  ipam_scope_id = module.ipam.private_default_scope_id

  cidrs = {
    rfc1918 = { cidr = "10.0.0.0/8", netmask_length = null }
  }
}

# 2. Regional pool: carves out space for us-east-1
module "regional_pool" {
  source = "../../modules/aws-ipam-pool"

  name                = "us-east-1"
  ipam_scope_id       = module.ipam.private_default_scope_id
  source_ipam_pool_id = module.top_pool.pool_id
  locale              = "us-east-1"

  cidrs = {
    regional = { cidr = null, netmask_length = 16 }
  }
}

# 3. Environment pool: further subdivides for production
module "prod_pool" {
  source = "../../modules/aws-ipam-pool"

  name                = "us-east-1-prod"
  ipam_scope_id       = module.ipam.private_default_scope_id
  source_ipam_pool_id = module.regional_pool.pool_id
  locale              = "us-east-1"

  cidrs = {
    prod = { cidr = null, netmask_length = 20 }
  }

  allocation_default_netmask_length = 24
  allocation_min_netmask_length     = 22
  allocation_max_netmask_length     = 28

  allocation_resource_tags = {
    Environment = "production"
  }
}
```

### IPv6 pool

```hcl
module "ipv6_pool" {
  source = "../../modules/aws-ipam-pool"

  name           = "corp-ipv6"
  ipam_scope_id  = module.ipam.private_default_scope_id
  address_family = "ipv6"

  cidrs = {
    primary = { cidr = "2001:db8::/32", netmask_length = null }
  }
}
```

### Pool with multiple CIDRs

```hcl
module "multi_cidr_pool" {
  source = "../../modules/aws-ipam-pool"

  name          = "multi-range"
  ipam_scope_id = module.ipam.private_default_scope_id

  # Each key is a stable identifier -- renaming keys destroys and recreates CIDRs
  cidrs = {
    rfc1918-10  = { cidr = "10.0.0.0/8",     netmask_length = null }
    rfc1918-172 = { cidr = "172.16.0.0/12",   netmask_length = null }
    rfc1918-192 = { cidr = "192.168.0.0/16",  netmask_length = null }
  }

  tags = {
    Team = "platform"
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
| address_family | The IP protocol assigned to this pool. Determines whether the pool manages IPv4 or IPv6 addresses. | `string` | `"ipv4"` | no |
| allocation_default_netmask_length | The default netmask length for allocations added to this pool. When a VPC requests a CIDR from this pool without specifying a size, this value is used. | `number` | `null` | no |
| allocation_max_netmask_length | The maximum netmask length that can be requested from this pool. Acts as a guardrail to prevent overly small allocations (e.g., /32 for a single IP). | `number` | `null` | no |
| allocation_min_netmask_length | The minimum netmask length that can be requested from this pool. Acts as a guardrail to prevent overly large allocations that could exhaust pool space. | `number` | `null` | no |
| allocation_resource_tags | A map of tags that resources must have to allocate CIDRs from this pool. Only resources with ALL of these tags can use this pool. Leave empty to allow any resource. | `map(string)` | `{}` | no |
| auto_import | Whether IPAM will automatically import any VPCs in your scope that fall within the CIDR range of this pool. | `bool` | `false` | no |
| aws_service | Limits which AWS service can use this pool. Currently only 'ec2' is supported. Set to null to allow any service. | `string` | `null` | no |
| cascade_delete | Enables you to quickly delete this IPAM pool and all resources within it, including CIDRs and allocations. Defaults to false for safety. | `bool` | `false` | no |
| cidrs | A map of CIDRs to provision into this pool. Keys are stable identifiers used as for_each keys. Each value specifies either 'cidr' (explicit block) or 'netmask_length' (allocate from parent by size), but not both. | `map(object({ cidr = optional(string), netmask_length = optional(number) }))` | `{}` | no |
| description | A description for the IPAM pool. | `string` | `""` | no |
| ipam_scope_id | The ID of the IPAM scope in which to create this pool. Use the private_default_scope_id or public_default_scope_id output from the aws-ipam module. | `string` | n/a | yes |
| locale | The AWS region where allocations from this pool are available. Required for regional (child) pools. Set to null for top-level pools that span all IPAM operating regions. | `string` | `null` | no |
| name | The name for the IPAM pool and related resources. Used in tags and resource naming. Alphanumeric and hyphens only, 1-64 characters. | `string` | n/a | yes |
| public_ip_source | The IP address source for pools in the public scope. Only relevant for public scope pools. Valid values: 'byoip', 'amazon'. | `string` | `null` | no |
| publicly_advertisable | Whether the IPv6 CIDR block is publicly advertisable over the internet. Only relevant for IPv6 pools with BYOIP. | `bool` | `false` | no |
| source_ipam_pool_id | The ID of the parent IPAM pool for creating a nested (child) pool. Set to null for top-level pools that provision CIDRs directly. | `string` | `null` | no |
| tags | A map of tags to apply to all resources created by this module. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| pool_arn | The ARN of the IPAM pool. |
| pool_cidr_ids | A map of CIDR keys to their IPAM pool CIDR resource IDs. |
| pool_cidrs | A map of user-provided CIDR keys to the provisioned CIDR blocks. For netmask_length allocations, the value is the CIDR assigned by IPAM. |
| pool_id | The ID of the IPAM pool. |
| pool_state | The state of the IPAM pool (e.g. create-complete, modify-complete). |

## Resources Created

| Name | Type | Condition |
|------|------|-----------|
| aws_vpc_ipam_pool.this | Resource | Always |
| aws_vpc_ipam_pool_cidr.this | Resource | `cidrs` is non-empty (one per entry) |

## Notes

### Relationship to the aws-ipam module

This module does not create an IPAM instance. It expects an IPAM to already exist and takes `ipam_scope_id` as its primary connection point. The typical flow is:

```
aws-ipam module  -->  ipam_scope_id  -->  aws-ipam-pool module (top-level)
                                      -->  aws-ipam-pool module (regional child)
                                      -->  aws-ipam-pool module (environment child)
```

Use `module.ipam.private_default_scope_id`, `module.ipam.public_default_scope_id`, or `module.ipam.custom_scope_ids["scope-name"]` from the `aws-ipam` module as the `ipam_scope_id` input here.

### CIDRs map key stability

The `cidrs` variable uses `for_each` internally, so the map keys are Terraform resource addresses. Changing a key (e.g., renaming `primary` to `main`) destroys the old CIDR and creates a new one. Choose stable, descriptive keys upfront:

```hcl
# Good -- keys describe what the CIDR is for
cidrs = {
  rfc1918-10 = { cidr = "10.0.0.0/8", netmask_length = null }
}

# Risky -- renaming this key later causes a destroy/create
cidrs = {
  a = { cidr = "10.0.0.0/8", netmask_length = null }
}
```

### Allocation guardrails

The three `allocation_*_netmask_length` variables control what VPCs can request from this pool:

| Variable | Effect | Example (IPv4) |
|----------|--------|----------------|
| `allocation_min_netmask_length` | Largest allowed allocation | `/16` = max 65,536 addresses |
| `allocation_max_netmask_length` | Smallest allowed allocation | `/28` = min 16 addresses |
| `allocation_default_netmask_length` | Used when VPC does not specify a size | `/24` = 256 addresses |

The module validates that `min <= default <= max` at plan time via lifecycle preconditions. For top-level pools that only feed child pools (not VPCs directly), you typically leave these unset.

### cascade_delete behavior

When `cascade_delete = true`, Terraform can destroy the pool even if it still contains CIDRs and allocations. This is useful for test/dev environments where you want clean teardown. In production, leave it `false` (the default) so that Terraform errors out if you try to destroy a pool that still has consumers. This forces you to clean up dependent resources first.

### Deferred features

Two AWS-supported features are not yet exposed by this module:

- **source_resource block** -- For resource planning pools that track usage of an existing VPC's CIDR space. Add when resource planning pool support is needed.
- **cidr_authorization_context block** -- The message and signature for BYOIP (Bring Your Own IP) ownership verification. Add when BYOIP pool support is needed.

Both are documented in `main.tf` comments for discoverability.

### Precondition validations

The module includes six lifecycle preconditions that catch configuration errors at plan time rather than during apply:

1. `publicly_advertisable` is only valid for IPv6 pools
2. `public_ip_source` is only valid for IPv4 pools
3. `allocation_min_netmask_length <= allocation_max_netmask_length`
4. `allocation_default_netmask_length` falls between min and max
5. IPv4 pools reject netmask lengths above 32
6. Explicit CIDRs must match the pool's `address_family`

### Tag merging

The module sets a `Name` tag from the `name` variable. Tags passed via `tags` are merged with this default. If you pass a `Name` key in `tags`, it will override the module's default.

### Phase 3: VPC module integration

This module is designed to feed CIDRs into VPCs via IPAM allocation. The upcoming VPC module integration will use `pool_id` from this module's outputs with `aws_vpc.ipv4_ipam_pool_id` to let VPCs draw their CIDR blocks from IPAM pools automatically, replacing hardcoded CIDR assignments.
