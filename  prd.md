# PRD: Generate CLAUDE.md + agent_docs for terraform-modules-lab

## Project Overview

`terraform-modules-lab` is a learning-focused Terraform project. The user builds reusable AWS infrastructure modules (VPC, Subnet, Security Group, IAM, EKS Cluster, Node Group), composes them into larger stacks (EKS Platform), and deploys across environments (dev, staging, prod). The project practices advanced Terraform: input validation, built-in testing (`.tftest.hcl`), mock providers, Terratest, dynamic blocks, `for_each`, and compositions. The scope is provider-agnostic — AWS is first but others may follow.

### The Golden Rule

**Claude Code must never write `.tf` files or `.tftest.hcl` files for the user.** This is a learning project. Claude can review, hint, explain, plan, validate, and generate docs — but never write Terraform code. If the user asks Claude to write Terraform, Claude should refuse politely and offer the appropriate subagent instead.

---

## Architecture: CLAUDE.md + agent_docs

This project uses **progressive disclosure**. The `CLAUDE.md` is lean and universally applicable. Detailed context lives in `agent_docs/` and is loaded only when relevant.

### Why This Architecture

- Claude Code injects `CLAUDE.md` into every session with a system note telling Claude it "may or may not be relevant" — so Claude may ignore bloated files
- Frontier models reliably follow ~150-200 instructions; Claude Code's system prompt uses ~50 already
- Adding more instructions degrades ALL instruction-following uniformly, not just the new ones
- Content that only matters for specific tasks (testing, module design, conventions) should not compete with universally needed context

### What Goes Where

| Content | Location | Why |
|---------|----------|-----|
| Project purpose, golden rule | `CLAUDE.md` | Every session needs this |
| Agent roster + routing | `CLAUDE.md` | Every session needs to know which agents exist |
| Pointer index to agent_docs | `CLAUDE.md` | So Claude knows where to find detail |
| Key commands (make targets) | `CLAUDE.md` | Universally needed |
| Top-level project structure | `CLAUDE.md` | Universally needed |
| Coding conventions | `agent_docs/coding_conventions.md` | Only when reviewing or writing code |
| Security standards | `agent_docs/security_standards.md` | Only when reviewing security |
| Testing guide | `agent_docs/testing_guide.md` | Only when writing or reviewing tests |
| Module design patterns | `agent_docs/module_design.md` | Only when designing modules |
| Learning progression | `agent_docs/learning_progression.md` | Only for context on what's next |
| Installed skills reference | `agent_docs/installed_skills.md` | Only when agents need skill context |

---

## CLAUDE.md Spec

**Hard limit: under 150 lines. Shorter is better.**

Must contain only these sections:

### 1. Project Purpose (2-3 sentences)
- What: Terraform module library — reusable modules, compositions, multi-env deployments
- Why: Learning project — user builds everything to develop advanced Terraform skills
- Scope: Provider-agnostic, starting with AWS

### 2. Golden Rule (1-2 sentences, within first 10 lines)
- Never write `.tf` or `.tftest.hcl` files for the user
- Offer the appropriate subagent instead (tf-explainer for concepts, tf-test-hint for test guidance)

### 3. Agent Roster (compact table)

| Agent | Purpose | Route When |
|-------|---------|------------|
| `tf-planner` | Design advisor — asks questions about module/composition design and module boundaries | User says "I want to build X", "should this be separate?" |
| `tf-explainer` | Concept explainer — explains features with generic examples | User says "how does X work?", "explain X" |
| `tf-validator` | Mechanical checks — fmt, validate, structural issues | User says "check my code", "is this valid?" |
| `tf-reviewer` | Deep review — best practices, security, naming, design. Reads `agent_docs/coding_conventions.md` and `agent_docs/security_standards.md` | User says "review this", "what am I missing?" |
| `tf-test-hint` | Testing guidance — suggests scenarios, edge cases, concepts. Reads `agent_docs/testing_guide.md` | User says "help me test", "what should I test?" |
| `tf-docs-gen` | Documentation — generates README.md for modules/compositions | User says "generate docs", "create README" |

### 4. Progressive Disclosure Index

Point Claude to `agent_docs/` with one-line descriptions:

```
agent_docs/
├── coding_conventions.md    — HashiCorp style guide: naming, file org, block ordering, versioning
├── security_standards.md    — Encryption, IAM, network security, secrets handling
├── testing_guide.md         — .tftest.hcl patterns, mock providers, Terratest, test naming
├── module_design.md         — Module hierarchy, boundary decisions, for_each vs count
├── learning_progression.md  — Phase 1-5 roadmap, current module status
└── installed_skills.md      — skills.sh skills installed, what each provides
```

Instruction: read the relevant file(s) before starting work. Don't read all of them — pick the ones that matter for the current task.

### 5. Key Commands

```
make fmt            — format all .tf files
make validate       — check formatting + syntax
make test           — run terraform test
make test-verbose   — run terraform test -verbose
make plan           — generate execution plan
make apply          — apply changes
```

### 6. Project Structure (brief, top-level only)

```
terraform-modules-lab/
├── modules/          — Reusable single-purpose modules (vpc, subnet, sg, iam, eks, node-group)
├── compositions/     — Modules wired into stacks (eks-platform)
├── environments/     — Thin wrappers with env-specific values (dev, staging, prod)
├── tests/            — Terratest Go files
├── agent_docs/       — Detailed reference docs (progressive disclosure)
├── .claude/          — Subagent definitions (settings.json)
├── Makefile
└── CLAUDE.md
```

### What CLAUDE.md must NOT contain
- Code snippets or examples
- Detailed conventions (block ordering, naming rules)
- Security checklists
- Testing patterns
- Learning progression details
- Skill descriptions
- Module status tables
- Anything that isn't needed in EVERY session

---

## agent_docs Specs

### agent_docs/coding_conventions.md

Cover these topics, preferring `file:line` pointers over copied code once modules exist:

**File organization** (per HashiCorp style guide):
- `versions.tf` — terraform block, required_version, required_providers
- `variables.tf` — all inputs, alphabetical
- `outputs.tf` — all outputs, alphabetical
- `main.tf` — primary resources
- `locals.tf` — local values
- `data.tf` — data sources (optional)

**Naming**:
- Lowercase with underscores
- Descriptive nouns excluding resource type
- `this` for singleton resources
- Context-prefixed variables (`vpc_cidr_block` not `cidr`)

**Variable block ordering**: description → type → default → validation → nullable

**Resource block ordering**: count/for_each → arguments → tags → depends_on → lifecycle

**Version pinning**:
- Terraform: `~> 1.9`
- Providers: `~> X.0`
- Modules in prod: exact version
- Modules in dev: `~> X.Y`

**General rules**:
- Every variable has description + type
- Every output has description
- `for_each` over `count` (except boolean toggles)
- No provider blocks inside modules
- Sensitive values marked `sensitive = true`

Note: Don't enforce these as linting rules — they're reference for the tf-reviewer agent. Formatting is handled by `terraform fmt`.

---

### agent_docs/security_standards.md

- Encryption at rest enabled by default
- No `0.0.0.0/0` in security groups unless explicitly justified
- Least privilege IAM policies
- Private networking by default
- `sensitive = true` on secrets and passwords
- No hardcoded credentials in `.tf` files
- No secrets in state — use AWS Secrets Manager / Parameter Store
- Enable logging and monitoring where applicable
- Security scanning: mention trivy, checkov as future integration

---

### agent_docs/testing_guide.md

**Test file naming**:
- Unit tests (plan mode): `*_unit_test.tftest.hcl`
- Mock tests: `*_mock_test.tftest.hcl`
- Integration tests (apply mode): `*_integration_test.tftest.hcl`

**Test location**: `tests/` subdirectory within each module

**What to test**:
- Default values produce valid config
- Custom variable values work correctly
- Validation blocks reject invalid input (`expect_failures`)
- Conditional resources created/skipped based on flags
- Outputs have expected values
- Resource counts match expectations

**Plan vs Apply**:
- `command = plan` — fast, free, for validating logic
- `command = apply` — creates real resources, for integration testing

**Mock providers** (Terraform 1.7+):
- Use for unit tests without cloud access
- Define `mock_provider` with `mock_resource` and `mock_data`
- Plan mode only
- Predictable return values

**Terratest** (Go-based):
- Lives in top-level `tests/` directory
- Pattern: Init → Apply → Assert → Destroy
- For complex integration assertions
- Phase 4 of learning progression

**Testing decision matrix** (from antonbabenko skill):
- Quick syntax check → `terraform validate`
- Pre-commit → validate + tflint
- Simple logic → built-in `terraform test`
- Go expertise / complex → Terratest
- Security focus → OPA, Sentinel
- Cost-sensitive → mock providers

---

### agent_docs/module_design.md

**Module hierarchy**:

| Level | Scope | Example |
|-------|-------|---------|
| Resource Module | Single logical group | VPC + subnets, SG + rules |
| Composition | Multiple modules wired together | EKS Platform = VPC + Subnet + IAM + EKS + Node Group |
| Environment | Thin wrapper with env values | dev, staging, prod calling a composition |

**Standard module structure**:
```
module-name/
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── locals.tf          # optional
├── data.tf            # optional
├── README.md
├── examples/
│   ├── minimal/
│   └── complete/
└── tests/
```

**Module boundary decisions** — when the user asks "should this be a separate module?", evaluate:
- Single responsibility: does adding it make the module do two unrelated things?
- Lifecycle: will this resource change independently?
- Reusability: would other compositions need it standalone?
- Blast radius: does separating reduce risk?
- Complexity: does it dilute the module's purpose with too many inputs?

**for_each vs count**:
- Boolean toggle → `count = var.create_x ? 1 : 0`
- Fixed number of identical resources → `count`
- Items may be reordered/removed → `for_each`
- Named access needed → `for_each` with map
- Multiple named resources → `for_each`

**Composition patterns**:
- Outputs from one module feed as inputs to the next
- Dependencies are implicit from references
- Use `depends_on` only when Terraform can't infer dependency
- Keep compositions focused on one architecture (e.g., EKS platform)

---

### agent_docs/learning_progression.md

**Phase 1 — Foundation Modules**:
1. VPC — CIDR, DNS support, tags, CIDR validation
2. Subnet — public/private, AZ distribution, for_each
3. Security Group — dynamic rules, port validation

**Phase 2 — Advanced Modules**:
4. IAM — roles, policies, assume role for EKS
5. EKS Cluster — control plane, add-ons, data sources
6. Node Group — managed nodes, scaling, taints/labels

**Phase 3 — Composition**:
7. EKS Platform composition — wire all modules
8. Environment configs — dev/staging/prod

**Phase 4 — Testing Depth**:
9. Mock provider tests — unit tests without cloud
10. Integration tests — real resources in test account
11. Terratest — Go-based complex assertions

**Phase 5 — Advanced Patterns**:
12. Terraform Stacks — component/deployment model
13. CI/CD — GitHub Actions: fmt → validate → test → plan → apply
14. Security scanning — trivy, checkov integration

**Current module status**:

| Module | Status |
|--------|--------|
| vpc | Planned |
| subnet | Planned |
| security-group | Planned |
| iam | Planned |
| eks-cluster | Planned |
| node-group | Planned |
| eks-platform (composition) | Planned |

Update this table as modules are completed.

---

### agent_docs/installed_skills.md

**Installed skills** (via skills.sh):

| Skill | Source | What It Provides |
|-------|--------|------------------|
| `terraform-style-guide` | `hashicorp/agent-skills` | Official HashiCorp file organization, naming, formatting, security hardening, version constraints |
| `terraform-test` | `hashicorp/agent-skills` | Complete `.tftest.hcl` syntax: run blocks, mock providers, expect_failures, parallel execution, CI/CD examples |
| `terraform-stacks` | `hashicorp/agent-skills` | Component/deployment pattern, multi-region, for_each on providers, deployment groups |
| `terraform-module-library` | `wshobson/agents` | Concrete module examples (VPC, EKS, RDS), composition patterns, Terratest examples |
| `terraform-skill` | `antonbabenko/terraform-skill` | Testing decision matrix, module hierarchy, count vs for_each, CI/CD workflows, security scanning, version management |

**When agents should reference skills**:
- `tf-reviewer` → `terraform-style-guide`, `terraform-skill`
- `tf-test-hint` → `terraform-test`, `terraform-skill`
- `tf-planner` → `terraform-module-library`, `terraform-stacks`, `terraform-skill`
- `tf-docs-gen` → `terraform-module-library`
- `tf-explainer` → any skill relevant to the concept being explained

Install commands (for reference):
```bash
npx skills add https://github.com/hashicorp/agent-skills --skill terraform-style-guide
npx skills add https://github.com/hashicorp/agent-skills --skill terraform-test
npx skills add https://github.com/hashicorp/agent-skills --skill terraform-stacks
npx skills add https://github.com/wshobson/agents --skill terraform-module-library
npx skills add https://github.com/antonbabenko/terraform-skill --skill terraform-skill
```