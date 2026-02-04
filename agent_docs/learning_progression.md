# Learning Progression

Roadmap for terraform-modules-lab skill development.

## Phase 1 — Foundation Modules

Build core networking modules with validation and testing:

1. **VPC** — CIDR configuration, DNS support, tags, CIDR validation
2. **Subnet** — Public/private subnets, AZ distribution, for_each patterns
3. **Security Group** — Dynamic ingress/egress rules, port validation

Skills practiced:
- Variable validation blocks
- Basic `.tftest.hcl` tests
- `for_each` with maps
- Dynamic blocks

## Phase 2 — Advanced Modules

Build IAM and EKS modules with more complex patterns:

4. **IAM** — Roles, policies, assume role documents for EKS
5. **EKS Cluster** — Control plane, add-ons, cluster data sources
6. **Node Group** — Managed node groups, scaling config, taints/labels

Skills practiced:
- JSON policy documents with `jsonencode()`
- Data sources for dynamic values
- Complex variable types (objects, maps of objects)
- Conditional resource creation

## Phase 3 — Composition

Wire modules together into deployable stacks:

7. **EKS Platform Composition** — VPC + Subnet + IAM + EKS + Node Group
8. **Environment Configs** — dev, staging, prod with different sizing

Skills practiced:
- Module composition patterns
- Output chaining between modules
- Environment-specific variable files
- Workspace or directory-based environments

## Phase 4 — Testing Depth

Comprehensive testing strategies:

9. **Mock Provider Tests** — Unit tests without cloud access
10. **Integration Tests** — Real resources in test account
11. **Terratest** — Go-based complex assertions

Skills practiced:
- Mock providers (Terraform 1.7+)
- `expect_failures` for validation testing
- Terratest patterns (Init → Apply → Assert → Destroy)
- Test organization and naming

## Phase 5 — Advanced Patterns

Production-ready infrastructure practices:

12. **Terraform Stacks** — Component/deployment model for multi-region
13. **CI/CD Pipeline** — GitHub Actions: fmt → validate → test → plan → apply
14. **Security Scanning** — trivy, checkov integration

Skills practiced:
- Deployment orchestration
- GitOps workflows
- Security as code
- Policy enforcement

---

## Current Module Status

| Module | Status | Notes |
|--------|--------|-------|
| vpc | Planned | Phase 1 |
| subnet | Planned | Phase 1 |
| security-group | Planned | Phase 1 |
| iam | Planned | Phase 2 |
| eks-cluster | Planned | Phase 2 |
| node-group | Planned | Phase 2 |
| eks-platform | Planned | Phase 3 (composition) |

**Update this table as modules are completed.**

## Next Steps

Start with Phase 1: build the VPC module with:
- Required variables: `cidr_block`, `name`
- Optional variables: `enable_dns_support`, `enable_dns_hostnames`, `tags`
- Validation: CIDR format
- Tests: defaults, custom values, invalid CIDR rejection
