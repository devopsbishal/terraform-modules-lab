# terraform-modules-lab

**Terraform | AWS | Learning Lab**

A learning-focused Terraform project for building reusable AWS infrastructure modules from scratch. The goal is to develop advanced Terraform skills by progressing through module creation, composition, environment management, and testing -- starting with core networking and working up to a full EKS platform.

Everything is built by hand. No copy-paste from registries.

> **Note:** This is a personal learning project, not production-ready infrastructure. Modules are intentionally simple to focus on learning Terraform patterns and testing practices.

## Project Structure

```
terraform-modules-lab/
├── modules/          # Reusable single-purpose modules (aws-vpc, aws-subnet, ...)
├── compositions/     # Modules wired into deployable stacks (planned)
├── environments/     # Thin wrappers with env-specific values (planned)
├── tests/            # Terratest Go files (planned)
├── agent_docs/       # Reference docs for coding conventions, security, testing, design
├── .claude/          # AI agent definitions (used with Claude Code CLI)
└── CLAUDE.md         # AI agent routing and project rules
```

## Module Status

| Module | Directory | Status | Phase | Test Coverage |
|--------|-----------|--------|-------|---------------|
| VPC | `modules/aws-vpc` | Complete | 1 | 2 test suites (defaults + validation) |
| Subnet | `modules/aws-subnet` | Complete | 1 | 2 test suites (defaults + validation, 20 runs) |
| Security Group | `modules/aws-security-group` | Planned | 1 | -- |
| IAM | `modules/aws-iam` | Planned | 2 | -- |
| EKS Cluster | `modules/aws-eks-cluster` | Planned | 2 | -- |
| Node Group | `modules/aws-node-group` | Planned | 2 | -- |
| EKS Platform | `compositions/eks-platform` | Planned | 3 | -- |

## Prerequisites

- **Terraform** ~> 1.13 (mock providers require 1.7+)
- **AWS Provider** ~> 6.0 (hashicorp/aws)
- **AWS credentials** configured via environment variables, shared credentials file, or IAM role

## Quick Start

Use a module by referencing its source path:

```hcl
module "vpc" {
  source = "./modules/aws-vpc"

  cidr_block = "10.0.0.0/16"
  name       = "my-vpc"

  tags = {
    Environment = "dev"
  }
}

module "subnet" {
  source = "./modules/aws-subnet"

  vpc_id            = module.vpc.vpc_id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  name              = "my-subnet"
}
```

Each module has its own README with full input/output documentation:

- [AWS VPC Module](modules/aws-vpc/README.md)
- [AWS Subnet Module](modules/aws-subnet/README.md)

## Commands

Run these from the project root. There is no Makefile yet -- use `terraform` directly from within each module directory:

```bash
# Format all .tf files
terraform fmt -recursive

# Validate a specific module
cd modules/aws-vpc && terraform init && terraform validate

# Run tests for a module
cd modules/aws-vpc && terraform test

# Run tests with detailed output
cd modules/aws-vpc && terraform test -verbose
```

## Testing Approach

All modules use **native Terraform testing** (`.tftest.hcl` files) with two categories:

| Test Type | File Pattern | Purpose |
|-----------|-------------|---------|
| Defaults / Unit | `defaults_unit_test.tftest.hcl` | Verify default values, optional overrides, tag merging |
| Validation | `validation_unit_test.tftest.hcl` | Confirm invalid inputs are rejected via `expect_failures` |

Tests run in **plan-only mode** with **mock providers**, so no AWS credentials or real resources are needed:

```hcl
mock_provider "aws" {}

run "test_defaults" {
  command = plan
  assert {
    condition     = aws_vpc.this.enable_dns_support == true
    error_message = "DNS support should default to true"
  }
}
```

## Learning Progression

The project follows a five-phase roadmap:

| Phase | Focus | Status |
|-------|-------|--------|
| **1 -- Foundation Modules** | VPC, Subnet, Security Group with validation and tests | In progress |
| **2 -- Advanced Modules** | IAM, EKS Cluster, Node Group with complex variable types | Not started |
| **3 -- Composition** | Wire modules into an EKS Platform stack, add environment configs | Not started |
| **4 -- Testing Depth** | Mock provider tests, integration tests, Terratest | Not started |
| **5 -- Advanced Patterns** | Terraform Stacks, CI/CD pipeline, security scanning | Not started |

Skills developed across phases: variable validation, `for_each`/`count` patterns, dynamic blocks, JSON policy documents, module composition, output chaining, environment-specific configs, and GitOps workflows.

See [agent_docs/learning_progression.md](agent_docs/learning_progression.md) for the full roadmap.

## AI-Assisted Workflow

This project uses [Claude Code](https://claude.ai/claude-code) with custom agents for code review, testing guidance, validation, and documentation generation. The AI never writes Terraform code directly -- it reviews, hints, and explains while the developer builds everything. Agent definitions live in `.claude/agents/` and routing rules are in `CLAUDE.md`.
