# terraform-modules-lab

A learning-focused Terraform project for building reusable infrastructure modules, composing them into stacks, and deploying across environments. Starting with AWS (VPC, Subnet, Security Group, IAM, EKS, Node Group) but provider-agnostic — other providers may follow. AI agents write the code; the user reviews, questions, and learns from it.

## Golden Rule

**AI writes, human reviews and learns.** Agents generate Terraform modules and tests. The user reviews all generated code with `tf-reviewer`, challenges design decisions, and builds understanding through the review process — not through manual HCL writing.

The value is in understanding **why** each decision was made, not in typing the configuration.

## Agents

| Agent | Purpose | Route When |
|-------|---------|------------|
| `tf-module-writer` | Generates .tf modules from docs URL + requirements | "build a module for X", "create the SG module" |
| `tf-reviewer` | Deep review, explains "why", applies changes, writes decisions.md | "review this", "why did it do X?", "apply changes" |
| `tf-test-writer` | Generates .tftest.hcl test files | "write tests for X", "generate tests" |
| `tf-planner` | Design advisor — module/composition design, boundaries | "I want to build X", "should this be separate?" |
| `tf-explainer` | Concept explainer — features with generic examples | "how does X work?", "explain X" |
| `tf-validator` | Mechanical checks — fmt, validate, structural issues | "check my code", "is this valid?" |
| `tf-docs-gen` | Documentation — generates README.md for modules | "generate docs", "create README" |

## Workflow

The standard workflow for creating a new module:

```
1. User provides: Terraform docs URL + requirements
2. tf-module-writer  → generates .tf files (opinionated, security-first)
3. tf-reviewer       → reviews code, explains "why" behind each decision
4. User              → discusses with reviewer, challenges decisions, learns
5. tf-reviewer       → applies agreed changes
6. tf-test-writer    → generates .tftest.hcl files
7. tf-reviewer       → reviews tests, user discusses
8. tf-reviewer       → applies test changes
9. tf-docs-gen       → generates README.md
10. tf-reviewer      → writes decisions.md (captures learnings from discussion)
```

Each module ends up with a `decisions.md` file capturing the "why" behind every significant choice.

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
