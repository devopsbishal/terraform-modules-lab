# terraform-modules-lab

A learning-focused Terraform project for building reusable infrastructure modules, composing them into stacks, and deploying across environments. Starting with AWS (VPC, Subnet, Security Group, IAM, EKS, Node Group) but provider-agnostic — other providers may follow. The user builds everything to develop advanced Terraform skills.

## Golden Rule

**Never write `.tf` or `.tftest.hcl` files for the user.** This is a learning project. You may review, hint, explain, plan, validate, and generate docs — but never write Terraform code. Offer the appropriate agent instead.

**Exception:** The `tf-review-consolidator` agent IS authorized to modify `.tf`, `.tfvars`, and `.tftest.hcl` files. It acts as the execution arm of the review pipeline — applying fixes that have already been reviewed and explained by upstream agents (e.g., `tf-reviewer`, `tf-test-hint`). The user learns the "why" from the reviewer; the consolidator handles the mechanical "how."

## Agents

| Agent | Purpose | Route When |
|-------|---------|------------|
| `tf-planner` | Design advisor — module/composition design, boundaries | "I want to build X", "should this be separate?" |
| `tf-explainer` | Concept explainer — features with generic examples | "how does X work?", "explain X" |
| `tf-validator` | Mechanical checks — fmt, validate, structural issues | "check my code", "is this valid?" |
| `tf-reviewer` | Deep review — best practices, security, naming, design | "review this", "what am I missing?" |
| `tf-test-hint` | Testing guidance — scenarios, edge cases, concepts | "help me test", "what should I test?" |
| `tf-docs-gen` | Documentation — generates README.md for modules | "generate docs", "create README" |

## Reference Docs (Progressive Disclosure)

Read the relevant file(s) before starting work — don't read all of them.

```
agent_docs/
├── coding_conventions.md    — HashiCorp style: naming, file org, block ordering, versioning
├── security_standards.md    — Encryption, IAM, network security, secrets handling
├── testing_guide.md         — .tftest.hcl patterns, mock providers, Terratest, test naming
├── module_design.md         — Module hierarchy, boundary decisions, for_each vs count
├── learning_progression.md  — Phase 1-5 roadmap, current module status
└── installed_skills.md      — skills.sh skills installed, what each provides
```

## Commands

```
make fmt            — format all .tf files
make validate       — check formatting + syntax
make test           — run terraform test
make test-verbose   — run terraform test -verbose
make plan           — generate execution plan
make apply          — apply changes
```

## Project Structure

```
terraform-modules-lab/
├── modules/          — Reusable single-purpose modules (vpc, subnet, sg, iam, eks, node-group)
├── compositions/     — Modules wired into stacks (eks-platform)
├── environments/     — Thin wrappers with env-specific values (dev, staging, prod)
├── tests/            — Terratest Go files
├── agent_docs/       — Detailed reference docs
├── .claude/          — Subagent definitions
├── Makefile
└── CLAUDE.md
```
