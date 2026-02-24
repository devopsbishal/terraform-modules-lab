# AWS VPC Module

Creates an AWS VPC with security-hardened defaults: VPC flow logs enabled out of the box, default security group locked down (no ingress/egress rules), and an optional Internet Gateway. Flow logs support CloudWatch Logs and S3 destinations, with automatic IAM role creation and confused deputy protection when using CloudWatch. Optional KMS encryption for the CloudWatch Log Group and IPv6 support are available.

## Usage

### Minimal (secure defaults)

```hcl
module "vpc" {
  source = "../../modules/aws-vpc"

  # Required
  name       = "my-app"
  cidr_block = "10.0.0.0/16"
}
```

This creates a VPC with DNS support, an Internet Gateway, flow logs to CloudWatch (30-day retention), and a locked-down default security group.

### Flow logs to S3

```hcl
module "vpc" {
  source = "../../modules/aws-vpc"

  # Required
  name       = "my-app"
  cidr_block = "10.0.0.0/16"

  # Flow logs to S3 bucket
  flow_log_destination_type = "s3"
  flow_log_destination_arn  = "arn:aws:s3:::my-flow-logs-bucket"

  tags = {
    Environment = "production"
    Team        = "platform"
  }
}
```

### Flow logs with KMS encryption

```hcl
module "vpc" {
  source = "../../modules/aws-vpc"

  # Required
  name       = "my-app"
  cidr_block = "10.0.0.0/16"

  # Encrypted CloudWatch flow logs
  flow_log_cloudwatch_kms_key_id                 = "arn:aws:kms:us-east-1:123456789012:key/12345678-abcd-1234-abcd-123456789012"
  flow_log_cloudwatch_log_group_retention_in_days = 90

  tags = {
    Environment = "production"
  }
}
```

### Private VPC (no IGW, no flow logs)

```hcl
module "vpc" {
  source = "../../modules/aws-vpc"

  # Required
  name       = "isolated-workload"
  cidr_block = "172.16.0.0/20"

  # No internet access
  create_igw       = false
  flow_log_enabled = false
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
| assign_generated_ipv6_cidr_block | Request an Amazon-provided IPv6 /56 CIDR block with a /56 prefix length. | `bool` | `false` | no |
| cidr_block | The IPv4 CIDR block for the VPC (e.g. 10.0.0.0/16). Must be between /16 and /24. | `string` | n/a | yes |
| create_igw | Whether to create an Internet Gateway and attach it to the VPC. | `bool` | `true` | no |
| enable_dns_hostnames | Whether to enable DNS hostnames in the VPC. Required for private hosted zones and EKS. | `bool` | `true` | no |
| enable_dns_support | Whether to enable DNS support in the VPC. Must be true for enable_dns_hostnames to work. | `bool` | `true` | no |
| enable_network_address_usage_metrics | Whether to enable Network Address Usage (NAU) metrics for the VPC. | `bool` | `false` | no |
| flow_log_cloudwatch_kms_key_id | The ARN of the KMS key to use for encrypting the CloudWatch Log Group for VPC flow logs. When null, CloudWatch default encryption is used. | `string` | `null` | no |
| flow_log_cloudwatch_log_group_retention_in_days | Number of days to retain VPC flow log events in CloudWatch Logs. Must be a valid CloudWatch retention period. | `number` | `30` | no |
| flow_log_destination_arn | The ARN of the destination for VPC flow logs (CloudWatch Log Group or S3 bucket). When destination type is cloud-watch-logs and this is null, a log group is created automatically. | `string` | `null` | no |
| flow_log_destination_type | The type of destination for VPC flow logs. Valid values: cloud-watch-logs, s3. | `string` | `"cloud-watch-logs"` | no |
| flow_log_enabled | Whether to enable VPC Flow Logs for network traffic visibility. | `bool` | `true` | no |
| flow_log_iam_role_arn | The ARN of an existing IAM role for VPC flow logs. Required when providing an external flow_log_destination_arn with cloud-watch-logs destination type. When null with auto-created log group, a role is created automatically. | `string` | `null` | no |
| flow_log_max_aggregation_interval | The maximum interval of time (in seconds) during which flow log records are captured and aggregated. Valid values: 60, 600. | `number` | `600` | no |
| flow_log_traffic_type | The type of traffic to capture in VPC flow logs. Valid values: ACCEPT, REJECT, ALL. | `string` | `"ALL"` | no |
| instance_tenancy | A tenancy option for instances launched into the VPC. Use 'dedicated' for compliance workloads requiring hardware isolation. | `string` | `"default"` | no |
| manage_default_security_group | Whether to adopt and lock down the VPC's default security group by removing all ingress and egress rules. | `bool` | `true` | no |
| name | The name for the VPC and related resources. Used in Name tags and resource naming. Must be 1-46 characters, alphanumeric and hyphens only. | `string` | n/a | yes |
| tags | A map of tags to apply to all resources created by this module. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| default_network_acl_id | The ID of the default network ACL created with the VPC. |
| default_route_table_id | The ID of the default route table created with the VPC. |
| default_security_group_id | The ID of the VPC's default security group. |
| flow_log_cloudwatch_log_group_arn | The ARN of the CloudWatch Log Group for VPC flow logs, if created. |
| flow_log_iam_role_arn | The ARN of the IAM role used by VPC flow logs. Returns the auto-created role ARN, the user-provided role ARN, or null. |
| flow_log_id | The ID of the VPC flow log, if created. |
| internet_gateway_id | The ID of the Internet Gateway, if created. |
| ipv6_association_id | The association ID for the IPv6 CIDR block. |
| ipv6_cidr_block | The IPv6 CIDR block of the VPC, if IPv6 is enabled. |
| main_route_table_id | The ID of the main route table associated with the VPC. |
| owner_id | The AWS account ID of the VPC owner. |
| vpc_arn | The ARN of the VPC. |
| vpc_cidr_block | The IPv4 CIDR block of the VPC. |
| vpc_id | The ID of the VPC. |

## Resources Created

| Name | Type | Condition |
|------|------|-----------|
| aws_vpc.this | Resource | Always |
| aws_internet_gateway.this | Resource | `create_igw = true` |
| aws_default_security_group.this | Resource | `manage_default_security_group = true` |
| aws_flow_log.this | Resource | `flow_log_enabled = true` |
| aws_cloudwatch_log_group.flow_log | Resource | Flow logs enabled + CloudWatch destination + no external ARN |
| aws_iam_role.flow_log | Resource | Same as CloudWatch Log Group |
| aws_iam_role_policy.flow_log | Resource | Same as CloudWatch Log Group |
| aws_caller_identity.current | Data source | Same as CloudWatch Log Group |
| aws_iam_policy_document.flow_log_assume_role | Data source | Same as CloudWatch Log Group |
| aws_iam_policy_document.flow_log_permissions | Data source | Same as CloudWatch Log Group |

## Tests

102 tests across 4 test files:

| File | Tests | Coverage |
|------|------:|----------|
| defaults_unit_test.tftest.hcl | 24 | Default values, auto-created resources, tag merging |
| validation_unit_test.tftest.hcl | 31 | Input validation rules (CIDR, name, retention, enums) |
| custom_unit_test.tftest.hcl | 27 | Custom configurations, S3 destination, external roles, KMS |
| edge_cases_unit_test.tftest.hcl | 20 | Boundary values, feature toggles, disabled combinations |

## Notes

### Security defaults

- **Flow logs enabled by default.** Traffic visibility out of the box. Disable explicitly with `flow_log_enabled = false`.
- **Default security group locked down.** The VPC's default SG is adopted and stripped of all rules, preventing accidental use. Disable with `manage_default_security_group = false`.
- **Least-privilege IAM.** The auto-created flow log role is scoped to `logs:CreateLogStream` and `logs:PutLogEvents` on the specific log group only.
- **Confused deputy protection.** The IAM trust policy includes `aws:SourceAccount` and `aws:SourceArn` conditions to prevent cross-account confused deputy attacks.

### CIDR block validation

The module enforces prefix lengths between /16 and /24:
- `/16` = 65,536 addresses (maximum)
- `/24` = 256 addresses (minimum)
- Blocks outside this range are rejected at plan time.

### Name length limit

The `name` variable is capped at 46 characters. This accounts for suffixes like `-vpc-flow-log-role` appended to derived resource names, keeping them within AWS limits (IAM role names max at 64 characters).

### Flow log destination combinations

| destination_type | destination_arn | iam_role_arn | Behavior |
|-----------------|----------------|--------------|----------|
| cloud-watch-logs | null | null | Auto-creates log group + IAM role |
| cloud-watch-logs | provided | provided | Uses external log group + external role |
| cloud-watch-logs | provided | null | **Error** -- external log group requires external role |
| s3 | provided | n/a | Sends to S3 bucket (no IAM role needed) |
| s3 | null | n/a | **Error** -- S3 destination requires an ARN |

### CloudWatch retention values

The `flow_log_cloudwatch_log_group_retention_in_days` variable only accepts values that CloudWatch Logs supports: 0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653.

### Tag merging

The module sets a `Name` tag from the `name` variable on all resources. Sub-resources get descriptive suffixes (e.g., `-igw`, `-default-sg`, `-flow-log`). Tags passed via `tags` are merged with these defaults.
