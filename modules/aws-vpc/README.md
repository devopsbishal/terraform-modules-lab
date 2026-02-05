# AWS VPC Module

Creates an AWS VPC with optional Internet Gateway. This module provisions a VPC with configurable DNS settings and enforces CIDR block size constraints between /16 and /24 to ensure reasonable network sizing.

## Usage

```hcl
module "vpc" {
  source = "../../modules/aws-vpc"

  # Required variables
  cidr_block = "10.0.0.0/16"

  # Optional variables
  name                 = "my-application-vpc"
  create_igw           = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = "production"
    Project     = "my-project"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | ~> 1.13.0 |
| aws | ~> 6.30.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cidr_block | The CIDR block for the VPC. | `string` | n/a | yes |
| create_igw | A boolean flag to create or not create an Internet Gateway. | `bool` | `true` | no |
| enable_dns_hostnames | A boolean flag to enable/disable DNS hostnames in the VPC. | `bool` | `true` | no |
| enable_dns_support | A boolean flag to enable/disable DNS support in the VPC. | `bool` | `true` | no |
| name | The name of the VPC. | `string` | `"terraform-vpc"` | no |
| tags | A map of tags to assign to the VPC. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| internet_gateway_id | The ID of the Internet Gateway, if created. |
| vpc_cidr_block | The CIDR block of the VPC. |
| vpc_id | The ID of the VPC. |

## Resources Created

| Name | Type |
|------|------|
| aws_vpc.this | resource |
| aws_internet_gateway.this | resource (conditional) |

## Notes

### CIDR Block Validation

The module enforces CIDR block constraints through input validation:

- The CIDR block must be a valid CIDR notation
- The prefix length must be between /16 and /24 (inclusive)
- CIDR blocks smaller than /16 (e.g., /8) are rejected to prevent overly large address spaces
- CIDR blocks larger than /24 (e.g., /28) are rejected to ensure sufficient IP addresses for subnets

Examples of valid CIDR blocks:
- `10.0.0.0/16` (65,536 addresses)
- `172.16.0.0/20` (4,096 addresses)
- `192.168.1.0/24` (256 addresses)

### Conditional Internet Gateway Creation

The Internet Gateway is created by default (`create_igw = true`). Set `create_igw = false` for:

- Private-only VPCs with no public internet access
- VPCs that will use Transit Gateway or VPN for external connectivity
- Isolated workloads that should not have internet access

When `create_igw = false`, the `internet_gateway_id` output returns `null`.

### DNS Settings

Both `enable_dns_support` and `enable_dns_hostnames` default to `true`. These settings are required for:

- Using private hosted zones in Route 53
- Resolving public DNS hostnames to private IP addresses within the VPC
- EKS clusters and many AWS managed services

### Tag Merging

The module automatically sets a `Name` tag based on the `name` variable. Additional tags passed via the `tags` variable are merged with this default. The same tags (including `Name`) are applied to both the VPC and Internet Gateway (with `-igw` suffix for the gateway).
