# Installed Skills

Skills installed via skills.sh for agent reference.

## Skills Reference

| Skill | Source | What It Provides |
|-------|--------|------------------|
| `terraform-style-guide` | hashicorp/agent-skills | Official HashiCorp file organization, naming, formatting, security hardening, version constraints |
| `terraform-test` | hashicorp/agent-skills | Complete `.tftest.hcl` syntax: run blocks, mock providers, expect_failures, parallel execution, CI/CD examples |
| `terraform-stacks` | hashicorp/agent-skills | Component/deployment pattern, multi-region, for_each on providers, deployment groups |
| `terraform-module-library` | wshobson/agents | Concrete module examples (VPC, EKS, RDS), composition patterns, Terratest examples |
| `terraform-skill` | antonbabenko/terraform-skill | Testing decision matrix, module hierarchy, count vs for_each, CI/CD workflows, security scanning, version management |

## Agent → Skill Mapping

| Agent | Primary Skills |
|-------|---------------|
| tf-reviewer | terraform-style-guide, terraform-skill |
| tf-test-hint | terraform-test, terraform-skill |
| tf-planner | terraform-module-library, terraform-stacks, terraform-skill |
| tf-docs-gen | terraform-module-library |
| tf-explainer | Any skill relevant to the concept |
| tf-validator | (uses terraform fmt/validate directly) |

## When to Reference Skills

- **Reviewing code** → Check terraform-style-guide for conventions
- **Designing tests** → Check terraform-test for syntax and patterns
- **Planning modules** → Check terraform-module-library for examples
- **Multi-region architecture** → Check terraform-stacks for patterns
- **Decision making** → Check terraform-skill for decision matrices

## Installation Commands

For reference, skills were installed with:

```bash
npx skills add https://github.com/hashicorp/agent-skills --skill terraform-style-guide
npx skills add https://github.com/hashicorp/agent-skills --skill terraform-test
npx skills add https://github.com/hashicorp/agent-skills --skill terraform-stacks
npx skills add https://github.com/wshobson/agents --skill terraform-module-library
npx skills add https://github.com/antonbabenko/terraform-skill --skill terraform-skill
```

## Skill Locations

After installation, skill content is available in `.claude/skills/` for agents to read when needed.
