# Module Design

Reference for tf-planner when advising on module structure and boundaries.

## Module Hierarchy

| Level | Scope | Example |
|-------|-------|---------|
| Resource Module | Single logical group | VPC + route tables, SG + rules |
| Composition | Multiple modules wired together | EKS Platform = VPC + Subnet + IAM + EKS + Node Group |
| Environment | Thin wrapper with env-specific values | dev, staging, prod calling a composition |

## Standard Module Structure

```
module-name/
├── main.tf           # Primary resources
├── variables.tf      # All inputs
├── outputs.tf        # All outputs
├── versions.tf       # Terraform and provider versions
├── locals.tf         # Local values (optional)
├── data.tf           # Data sources (optional)
├── README.md         # Module documentation
├── examples/
│   ├── minimal/      # Simplest working config
│   └── complete/     # All features enabled
└── tests/
    ├── *_unit_test.tftest.hcl
    └── *_integration_test.tftest.hcl
```

## Module Boundary Decisions

When the user asks "should this be a separate module?", evaluate:

### Single Responsibility
Does adding this make the module do two unrelated things?
- Yes → Separate module
- No → Keep together

### Lifecycle
Will this resource change independently of others?
- Yes → Separate module
- No → Keep together

### Reusability
Would other compositions need it standalone?
- Yes → Separate module
- No → Can stay together

### Blast Radius
Does separating reduce risk of unintended changes?
- Yes → Separate module
- No → Keep together

### Complexity
Does it dilute the module's purpose with too many inputs?
- Yes → Separate module
- No → Keep together

## for_each vs count

| Scenario | Use |
|----------|-----|
| Boolean toggle (create/don't create) | `count = var.create_x ? 1 : 0` |
| Fixed number of identical resources | `count` |
| Items may be reordered or removed | `for_each` |
| Need named access to resources | `for_each` with map |
| Multiple named resources | `for_each` |

### count Example (Boolean Toggle)
```hcl
resource "aws_nat_gateway" "this" {
  count = var.create_nat_gateway ? 1 : 0
  # ...
}
```

### for_each Example (Named Resources)
```hcl
resource "aws_subnet" "private" {
  for_each = var.private_subnets

  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  # ...
}
```

## Composition Patterns

### Outputs Feed Inputs
```hcl
module "vpc" {
  source = "../modules/vpc"
  # ...
}

module "subnet" {
  source = "../modules/subnet"
  vpc_id = module.vpc.vpc_id  # Output → Input
  # ...
}
```

### Implicit Dependencies
Terraform infers dependencies from references. Use `depends_on` only when Terraform cannot infer the dependency.

### Focused Compositions
Keep compositions focused on one architecture:
- `eks-platform/` — everything needed for EKS
- `rds-platform/` — everything needed for RDS (future)

Don't create a monolithic composition that does everything.

## Design Questions for tf-planner

When helping design a module, ask:

1. What is the single responsibility of this module?
2. What are the minimum required inputs?
3. What outputs will consumers need?
4. What validations should reject bad input?
5. What conditional features might be needed?
6. How will this compose with other modules?
