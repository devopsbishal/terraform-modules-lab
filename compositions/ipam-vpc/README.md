# IPAM-VPC Composition

Creates an end-to-end AWS IPAM hierarchy and a VPC that allocates its CIDR from it. The composition provisions an IPAM instance, a 3-tier pool hierarchy (top-level, regional, environment), and a VPC whose IPv4 CIDR is automatically assigned by the environment pool. Designed for exploration and learning -- apply it, inspect the resources in the AWS console, then destroy cleanly.

## Architecture

```
IPAM Instance
  |
  +-- Top-level pool (/8)        e.g. 10.0.0.0/8
        |
        +-- Regional pool (/10)       auto-allocated from parent
              |
              +-- Environment pool (/14)   auto-allocated from parent
                    |
                    +-- VPC (/20)              auto-allocated from parent
```

Each pool carves a progressively smaller slice from its parent. The VPC does not specify a CIDR directly -- it requests a `/20` from the environment pool and IPAM assigns one automatically.

## Usage

This composition contains a provider block and must be applied directly as a root module. It cannot be called as a child module.

```bash
cd compositions/ipam-vpc
terraform init
terraform apply
```

Override defaults with `-var` flags or a `terraform.tfvars` file:

```bash
terraform apply \
  -var="aws_region=us-east-1" \
  -var="aws_profile=my-aws-profile" \
  -var="environment=dev" \
  -var="project_name=platform"
```

## Requirements

| Name | Version |
|------|---------|
| terraform | ~> 1.9 |
| aws | ~> 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| aws_profile | The AWS CLI profile to use for authentication. Maps to the provider's `profile` argument. | `string` | `"default"` | no |
| aws_region | The AWS region to deploy into. Used for the provider, IPAM operating region, and pool locale. | `string` | `"us-west-2"` | no |
| environment | The environment name (e.g. dev, staging, production). Used in resource naming and the pool hierarchy. | `string` | `"production"` | no |
| flow_log_enabled | Whether to enable VPC Flow Logs. Disabled by default in this composition since IPAM exploration does not require network traffic visibility. | `bool` | `false` | no |
| ipam_tier | The IPAM tier. `free` provides basic functionality at no cost. `advanced` enables resource discovery and Organizations integration but incurs hourly charges. | `string` | `"advanced"` | no |
| project_name | A short project identifier used as a prefix in resource names (e.g. `lab`, `platform`). Keeps names unique when multiple compositions share an account. | `string` | `"lab"` | no |
| tags | Additional tags to merge with the default tags applied to all resources. | `map(string)` | `{}` | no |
| top_level_cidr | The RFC 1918 CIDR block provisioned into the top-level pool. This is the supernet from which all child pools and VPCs are carved. | `string` | `"10.0.0.0/8"` | no |
| vpc_netmask_length | The netmask length for the VPC CIDR allocated from the environment pool. `/20` provides 4,096 addresses. | `number` | `20` | no |

## Outputs

| Name | Description |
|------|-------------|
| environment_pool_cidrs | The CIDRs assigned to the environment pool. |
| environment_pool_id | The ID of the environment IPAM pool. |
| ipam_arn | The ARN of the IPAM instance. |
| ipam_id | The ID of the IPAM instance. |
| regional_pool_cidrs | The CIDRs assigned to the regional pool. |
| regional_pool_id | The ID of the regional IPAM pool. |
| summary | A human-readable summary of the deployed IPAM hierarchy and VPC. |
| top_level_pool_cidrs | The CIDRs provisioned in the top-level pool. |
| top_level_pool_id | The ID of the top-level IPAM pool. |
| vpc_arn | The ARN of the VPC. |
| vpc_cidr_block | The IPv4 CIDR block assigned to the VPC by IPAM. |
| vpc_id | The ID of the VPC. |

## Dependencies

This is a composition that wires together three modules in a strict dependency chain:

- **`module.ipam`** (`modules/aws-ipam`) -- Creates the IPAM instance and provides the `private_default_scope_id` that all pools need.
- **`module.top_level_pool`** (`modules/aws-ipam-pool`) -- Top-level pool under the IPAM's private default scope. Provisions the RFC 1918 supernet (default `10.0.0.0/8`) as an explicit CIDR.
- **`module.regional_pool`** (`modules/aws-ipam-pool`) -- Child of the top-level pool. Sets `locale` to the target region and auto-allocates a `/10` from the parent.
- **`module.environment_pool`** (`modules/aws-ipam-pool`) -- Child of the regional pool. Auto-allocates a `/14` and serves as the direct source for VPC allocations.
- **`module.vpc`** (`modules/aws-vpc`) -- Requests a `/20` CIDR from the environment pool via `ipv4_ipam_pool_id`. No static CIDR is specified.

**Data flow:**

```
ipam.private_default_scope_id
  --> top_level_pool.ipam_scope_id
  --> regional_pool.ipam_scope_id
  --> environment_pool.ipam_scope_id

top_level_pool.pool_id --> regional_pool.source_ipam_pool_id
regional_pool.pool_id  --> environment_pool.source_ipam_pool_id
environment_pool.pool_id --> vpc.ipv4_ipam_pool_id
```

Terraform resolves most ordering through these references. The `pool_id` output additionally uses `depends_on` to wait for CIDR provisioning (see Notes).

## Notes

- **IPAM tier defaults to `advanced`.** The `free` tier does not support private scopes, which this composition requires. The `advanced` tier incurs hourly charges (~$0.0027/hr per active IP address in your VPC). For short exploration sessions the cost is negligible, but do not leave it running indefinitely.
- **`cascade_delete = true` on all pools.** This allows `terraform destroy` to clean up the entire pool hierarchy in one pass. Without it, you would need to manually deallocate CIDRs before destroying pools.
- **Destroy takes 5-10+ minutes.** IPAM CIDR deallocation propagates through the pool hierarchy asynchronously. Terraform will wait for each pool's CIDRs to fully deprovision before deleting the pool itself. This is normal AWS behavior, not a Terraform issue.
- **Race condition fix in the pool module.** The `pool_id` output in `modules/aws-ipam-pool` uses `depends_on = [aws_vpc_ipam_pool_cidr.this]` to ensure the pool's CIDRs are fully provisioned before any child pool or VPC tries to allocate from it. Without this, child allocations could fail with "pool has no provisioned CIDRs."
- **Child pools require `locale`.** The `aws-ipam-pool` module has a precondition enforcing that any pool with a `source_ipam_pool_id` (i.e., a child pool) must also set `locale`. This is an AWS requirement -- allocations from a parent pool must target a specific region.
- **Pool sizing is hardcoded in `locals.tf`.** The regional (`/10`) and environment (`/14`) netmask lengths are local values, not variables. This keeps the interface simple for exploration. If you need different sizing, edit `locals.tf` directly.
- **Flow logs are disabled by default.** Unlike the standalone `aws-vpc` module (which defaults to enabled), this composition disables flow logs since the focus is IPAM exploration, not network traffic analysis. Set `flow_log_enabled = true` to re-enable.
- **All resources are tagged.** The provider applies `Managed-By = Terraform` via `default_tags`. The composition adds `Composition`, `Environment`, and `Project` tags to every resource.
