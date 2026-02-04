# Testing Guide

Reference for tf-test-hint when guiding test development.

## Test File Naming

| Type | Suffix | Mode | Purpose |
|------|--------|------|---------|
| Unit | `*_unit_test.tftest.hcl` | plan | Validate logic without cloud |
| Mock | `*_mock_test.tftest.hcl` | plan | Predictable return values |
| Integration | `*_integration_test.tftest.hcl` | apply | Real resources in test account |

## Test Location

Tests live in a `tests/` subdirectory within each module:

```
modules/vpc/
├── main.tf
├── variables.tf
├── outputs.tf
└── tests/
    ├── defaults_unit_test.tftest.hcl
    ├── validation_unit_test.tftest.hcl
    └── complete_integration_test.tftest.hcl
```

## What to Test

- **Default values** — produce valid configuration
- **Custom values** — work correctly when overridden
- **Validation blocks** — reject invalid input (`expect_failures`)
- **Conditional resources** — created/skipped based on flags
- **Outputs** — have expected values
- **Resource counts** — match expectations

## Plan vs Apply Mode

### Plan Mode (`command = plan`)
- Fast, free, no cloud access needed
- Validates logic and structure
- Use for unit tests and validation tests
- Cannot verify actual resource creation

### Apply Mode (`command = apply`)
- Creates real resources
- For integration testing
- Requires cloud credentials and test account
- Cleans up resources after test

## Mock Providers (Terraform 1.7+)

Use for unit tests without cloud access:

```hcl
mock_provider "aws" {
  mock_resource "aws_vpc" {
    defaults = {
      id         = "vpc-mock123"
      arn        = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock123"
      cidr_block = "10.0.0.0/16"
    }
  }
}

run "test_with_mock" {
  command = plan
  # assertions here
}
```

Key points:
- Plan mode only
- Predictable return values
- Define `mock_resource` and `mock_data` as needed
- No cloud credentials required

## expect_failures

Test that validation blocks correctly reject bad input:

```hcl
run "test_invalid_cidr" {
  command = plan

  variables {
    cidr_block = "invalid-cidr"
  }

  expect_failures = [
    var.cidr_block
  ]
}
```

## Terratest (Go-based)

For complex integration assertions. Lives in top-level `tests/` directory:

```
tests/
├── vpc_test.go
└── eks_test.go
```

Pattern:
1. Init
2. Apply
3. Assert (using Go assertions)
4. Destroy

Use when:
- Need complex assertion logic
- Want to test external behavior (HTTP endpoints, DNS)
- Require parallel test execution with dependencies

## Testing Decision Matrix

| Need | Tool |
|------|------|
| Quick syntax check | `terraform validate` |
| Pre-commit validation | validate + tflint |
| Simple logic tests | Built-in `terraform test` |
| Go expertise / complex assertions | Terratest |
| Security policy testing | OPA, Sentinel |
| Cost-sensitive testing | Mock providers |

## Commands

```bash
make test           # Run all terraform tests
make test-verbose   # Run with verbose output
terraform test -filter=tests/validation_unit_test.tftest.hcl  # Single file
```
