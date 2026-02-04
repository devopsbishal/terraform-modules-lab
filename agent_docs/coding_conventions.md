# Coding Conventions

Reference for tf-reviewer and other agents. Formatting is handled by `terraform fmt`.

## File Organization (HashiCorp Style Guide)

| File | Contents |
|------|----------|
| `versions.tf` | terraform block, required_version, required_providers |
| `variables.tf` | All inputs, alphabetical order |
| `outputs.tf` | All outputs, alphabetical order |
| `main.tf` | Primary resources |
| `locals.tf` | Local values |
| `data.tf` | Data sources (optional) |

## Naming

- Lowercase with underscores: `eks_cluster`, `node_group`
- Descriptive nouns excluding resource type: `main` not `main_vpc`
- `this` for singleton resources: `aws_vpc.this`
- Context-prefixed variables: `vpc_cidr_block` not `cidr`

## Variable Block Ordering

```hcl
variable "example" {
  description = "..."   # 1. description (required)
  type        = string  # 2. type (required)
  default     = "..."   # 3. default (optional)
  validation {          # 4. validation (optional)
    condition     = ...
    error_message = "..."
  }
  nullable    = false   # 5. nullable (optional)
}
```

## Resource Block Ordering

```hcl
resource "aws_example" "this" {
  count    = ...        # 1. count/for_each
  for_each = ...

  name     = ...        # 2. arguments (alphabetical)
  setting  = ...

  tags = ...            # 3. tags

  depends_on = [...]    # 4. depends_on

  lifecycle {           # 5. lifecycle
    ...
  }
}
```

## Version Pinning

| Context | Constraint | Example |
|---------|------------|---------|
| Terraform | Pessimistic | `~> 1.9` |
| Providers | Pessimistic major | `~> 5.0` |
| Modules (prod) | Exact | `= 1.2.3` |
| Modules (dev) | Pessimistic minor | `~> 1.2` |

## General Rules

- Every variable has `description` + `type`
- Every output has `description`
- Prefer `for_each` over `count` (except boolean toggles)
- No provider blocks inside modules
- Mark sensitive values: `sensitive = true`
- No hardcoded credentials in `.tf` files

## Examples (Reference Once Modules Exist)

Once modules are built, reference them instead of the examples above:
- File organization: `modules/vpc/`
- Variable ordering: `modules/vpc/variables.tf`
- Resource ordering: `modules/vpc/main.tf`
