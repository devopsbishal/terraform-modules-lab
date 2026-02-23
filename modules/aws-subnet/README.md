# AWS Subnet Module

Creates an AWS subnet within a specified VPC. This module provisions a single subnet with configurable availability zone, CIDR block, and public IP mapping. Input validation enforces correct formats for VPC IDs, CIDR notation, and availability zone patterns.

## Usage

```hcl
module "subnet" {
  source = "../../modules/aws-subnet"

  # Required variables
  vpc_id            = "vpc-0abcdef1234567890"
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  # Optional variables
  name                    = "my-application-subnet"
  map_public_ip_on_launch = false

  tags = {
    Environment = "production"
    Project     = "my-project"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | ~> 1.13 |
| aws | ~> 6.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| availability_zone | The AZ where the subnet will be created. | `string` | n/a | yes |
| cidr_block | The IPv4 CIDR block for the subnet (e.g., '10.0.1.0/24'). Must be a subset of the VPC's CIDR block. | `string` | n/a | yes |
| map_public_ip_on_launch | Whether to assign a public IP address to instances launched in this subnet. | `bool` | `false` | no |
| name | The name of the subnet. | `string` | `"terraform-subnet"` | no |
| tags | A map of tags to assign to the subnet. | `map(string)` | `{}` | no |
| vpc_id | The ID of the VPC in which to create the subnet. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| subnet_id | The ID of the subnet. |

## Resources Created

| Name | Type |
|------|------|
| aws_subnet.this | resource |

## Notes

### Input Validation

The module enforces strict input validation on three required variables:

- **cidr_block** -- Must be valid CIDR notation (e.g., `10.0.1.0/24`). Invalid octets, missing prefix lengths, and out-of-range prefixes are all rejected.
- **vpc_id** -- Must match the pattern `vpc-` followed by lowercase hexadecimal characters. Uppercase hex, wrong prefixes (e.g., `subnet-`), and bare `vpc-` without a suffix are rejected.
- **availability_zone** -- Must match the pattern `{region}{az-letter}` (e.g., `us-east-1a`). Region-only values like `us-east-1` without the trailing letter suffix are rejected.

### Public IP Mapping

The `map_public_ip_on_launch` variable defaults to `false`. Set it to `true` for public subnets where instances need automatic public IP assignment. For private subnets (the common case), leave the default.

### Tag Merging

The module sets a `Name` tag from the `name` variable and merges it with any additional tags passed via `tags`. If you include a `Name` key in `tags`, it will override the value set by `name` due to `merge()` precedence (the second map wins).

### Test Coverage

The module includes two test suites under `tests/`:

| Test File | Scenarios | What It Covers |
|-----------|-----------|----------------|
| `defaults_unit_test.tftest.hcl` | 6 runs | Default values, public IP toggle, custom name, tag merging, tag override precedence, long-form VPC IDs |
| `validation_unit_test.tftest.hcl` | 14 runs | Rejection of invalid CIDR blocks, invalid VPC IDs, invalid availability zones, and empty names |

Run tests with:

```bash
make test           # from project root
make test-verbose   # for detailed output
```
