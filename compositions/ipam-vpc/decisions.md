# Design Decisions: IPAM-VPC Composition

Captures the "why" behind every significant design choice made during the
creation, exploration, and refinement of this composition. Unlike module-level
decisions.md files that focus on variable design and resource boundaries, this
file focuses on composition-level choices: why a composition exists, how modules
are wired together, what was learned from real AWS deployment, and what bugs
were found and fixed along the way.

This is the first composition in the project. It establishes patterns that
future compositions (e.g., eks-platform) will follow.

---

## Table of Contents

**Why This Composition Exists**
1. [Living Composition Over Test Fixture](#1-living-composition-over-test-fixture)
2. [No environments/ Wrapper](#2-no-environments-wrapper)

**Architecture**
3. [3-Tier Pool Hierarchy](#3-3-tier-pool-hierarchy)
4. [Variable Surface Reduction](#4-variable-surface-reduction)
5. [Pool Netmask Sizing Hardcoded in Locals](#5-pool-netmask-sizing-hardcoded-in-locals)

**Configuration Choices**
6. [IPAM Tier Must Be "advanced"](#6-ipam-tier-must-be-advanced)
7. [cascade_delete = true Everywhere](#7-cascade_delete--true-everywhere)
8. [Flow Logs Disabled by Default](#8-flow-logs-disabled-by-default)
9. [Provider default_tags for Managed-By](#9-provider-default_tags-for-managed-by)

**Bugs Found During Exploration**
10. [Locale Precondition Added to aws-ipam-pool Module](#10-locale-precondition-added-to-aws-ipam-pool-module)
11. [pool_id Output depends_on Fix](#11-pool_id-output-depends_on-fix)

**Operational Learnings**
12. [Destroy Takes 5-10+ Minutes](#12-destroy-takes-5-10-minutes)
13. [Module Renames During Refactor](#13-module-renames-during-refactor)

---

## 1. Living Composition Over Test Fixture

**Decision:** Build a persistent, deployable composition in `compositions/`
rather than a `.tftest.hcl` integration test that creates and destroys
resources in a single run.

**Rationale:** The design advisor recommended Option C: a `terraform test`
approach using module blocks to wire the three modules together, validate with
assertions, then destroy. This is clean and automated, but it optimizes for
CI/CD -- not for learning.

The user wanted to:
- Deploy to AWS and explore resources in the console
- Try different configurations (change pool sizes, add VPCs, modify the
  hierarchy)
- Keep the environment running between sessions
- Build muscle memory with `terraform plan`, `terraform apply`,
  `terraform state`

A test fixture runs once and destroys. A composition gives a persistent
environment where you can iteratively experiment. The user built the 3-tier
pool hierarchy themselves during this exploration -- that hands-on discovery
would not have happened in a test-and-destroy workflow.

**Alternatives Considered:** (1) `.tftest.hcl` with `command = apply` -- clean
and automated, but no persistence between runs and no console exploration.
(2) An example directory (`modules/aws-vpc/examples/ipam/`) -- possible, but
examples are typically minimal and not intended for ongoing experimentation.
(3) This composition -- a first-class deployable stack that wires modules
together, has its own state, and can be applied and destroyed repeatedly.

**Tradeoff:** Compositions require manual cleanup (`terraform destroy`).
Test fixtures clean up automatically. For a learning context, the manual
cleanup is acceptable -- it is itself a learning opportunity (see Decision 12
about destroy times).

---

## 2. No environments/ Wrapper

**Decision:** Apply the composition directly with `terraform apply` from
`compositions/ipam-vpc/`. Do not create an `environments/dev/` wrapper that
calls the composition as a module.

**Rationale:** The project structure defines three levels: modules,
compositions, and environments. In production, the environments layer adds
env-specific values (different CIDR ranges, different instance sizes, different
tags per environment). For exploration, this indirection slows the feedback
loop without adding value.

The composition already has sensible defaults for every variable. Running
`terraform apply` from the composition directory is one step. Adding an
environments wrapper would mean:
1. Creating `environments/dev/main.tf` that calls `../../compositions/ipam-vpc`
2. Passing through variables that the composition already defaults
3. Navigating to a different directory to run commands
4. Debugging through an extra layer of module indirection

None of this helps with IPAM exploration. The environments layer should be
introduced when there is a real multi-env deployment need -- for example, when
the same composition needs to be deployed to dev, staging, and production with
different pool sizes and CIDR ranges.

**Revisit when:** The project has a composition that genuinely deploys to
multiple environments with different configurations.

---

## 3. 3-Tier Pool Hierarchy

**Decision:** The composition creates a 3-tier pool hierarchy:

```
Top-level pool (/8)  -->  Regional pool (/10)  -->  Environment pool (/14)  -->  VPC (/20)
```

**Rationale:** This mirrors real organizational patterns in enterprise AWS
environments:

- **Top-level pool** holds the RFC 1918 supernet (`10.0.0.0/8` by default).
  This is the master address space for the entire organization. It has no
  `locale` because it spans all regions.

- **Regional pool** carves a `/10` from the top-level. It sets `locale` to
  the target region, which is required by AWS for any pool that VPCs will
  allocate from (directly or transitively). A `/10` gives ~4 million addresses
  per region -- room for many environments.

- **Environment pool** carves a `/14` from the regional pool. This is where
  organizational boundaries happen: production, staging, and dev each get
  their own pool with separate address space. A `/14` gives ~262,000
  addresses -- enough for many VPCs within one environment.

- **VPC** requests a `/20` from the environment pool. IPAM assigns the next
  available block automatically. A `/20` gives 4,096 addresses -- enough for
  exploration without wasting pool space.

The user built this hierarchy themselves during hands-on exploration, starting
with a single pool and progressively adding layers to understand how IPAM
parent-child relationships work.

**Alternatives Considered:** (1) A 2-tier hierarchy (top-level + VPC pool) --
simpler but does not demonstrate the regional and environment segmentation that
makes IPAM valuable in practice. (2) A 4-tier hierarchy (adding team-level
pools) -- more realistic for large organizations but unnecessary complexity for
learning. The 3-tier structure hits the sweet spot: enough depth to understand
the pattern, not so much that setup becomes tedious.

**Sizing rationale:** The netmask progression (`/8` -> `/10` -> `/14` -> `/20`)
leaves room at each tier. A `/10` is 2 bits from `/8`, giving 4 regional pools
per top-level. A `/14` is 4 bits from `/10`, giving 16 environment pools per
region. A `/20` is 6 bits from `/14`, giving 64 VPCs per environment pool.
These are generous allocations for exploration.

---

## 4. Variable Surface Reduction

**Decision:** The composition exposes 9 variables to the caller, despite the
three underlying modules having ~40 variables collectively.

**Rationale:** A composition's job is to make opinionated choices so consumers
do not have to. The 9 exposed variables are the ones a user would reasonably
want to change:

| Variable | Why Exposed |
|----------|-------------|
| `aws_profile` | Authentication varies per user |
| `aws_region` | Region is a deployment choice |
| `environment` | Names the environment tier |
| `flow_log_enabled` | Optional feature toggle |
| `ipam_tier` | Cost vs. capability tradeoff |
| `project_name` | Namespace for resource names |
| `tags` | Organizational tagging policies vary |
| `top_level_cidr` | RFC 1918 block is an organizational choice |
| `vpc_netmask_length` | VPC size depends on workload needs |

Everything else is hardcoded in the composition because it is an architectural
decision of this specific stack:
- Pool hierarchy structure (3-tier) is in `main.tf`
- Pool netmask sizes (`/10`, `/14`) are in `locals.tf`
- `cascade_delete = true` on all pools (Decision 7)
- Pool names derived from project, region, and environment in `locals.tf`
- IPAM operating region matches the provider region

If a future consumer needs to change one of the hardcoded values, they should
either edit the composition directly (for one-off changes) or fork it into a
new composition with a different architectural opinion.

**Tradeoff:** Reduced flexibility for reduced complexity. A consumer cannot
change pool netmask sizes without editing `locals.tf`. This is intentional --
pool sizing is tightly coupled to the hierarchy design and should not be
changed independently.

---

## 5. Pool Netmask Sizing Hardcoded in Locals

**Decision:** The regional netmask (`/10`) and environment netmask (`/14`) are
local values, not input variables.

```hcl
locals {
  regional_netmask    = 10
  environment_netmask = 14
}
```

**Rationale:** These values are part of the composition's architectural opinion,
not consumer choices. The 3-tier hierarchy (Decision 3) defines fixed
relationships between pool sizes. Changing the regional netmask from `/10` to
`/12` without also reconsidering the environment netmask and VPC netmask could
create pools that do not fit within their parents.

Making these variables would imply they are independently tunable, which they
are not. A user who wants different sizing needs to rethink the entire
hierarchy -- which means creating a different composition, not tweaking
variables on this one.

The VPC netmask length IS a variable (`vpc_netmask_length`, default `/20`)
because it represents a consumer choice: how large should each VPC be? This
can vary independently of the pool hierarchy as long as the VPC fits within
the environment pool.

**Alternatives Considered:** Exposing all three netmask values as variables
with validation ensuring child <= parent. Rejected because it adds 2 variables,
requires cross-variable preconditions, and invites misconfiguration for no
real benefit. A user exploring IPAM should not need to think about pool sizing
on the first `terraform apply`.

---

## 6. IPAM Tier Must Be "advanced"

**Decision:** `var.ipam_tier` defaults to `"advanced"`, overriding the
aws-ipam module's default of `"free"`.

**Rationale:** The design advisor originally recommended the free tier to
minimize cost, and the aws-ipam module defaults to `"free"` for the same
reason (see Decision 4 in aws-ipam's decisions.md). However, the user
discovered during real deployment that the free tier does not support private
scopes.

This composition uses `module.ipam.private_default_scope_id` as the
`ipam_scope_id` for all three pools. On the free tier, the user was unable to
even create private scopes -- the feature is gated behind the advanced tier.
Without private scopes, the entire pool hierarchy that this composition builds
is non-functional.

The advanced tier incurs hourly charges (~$0.0027/hr per active IP address in
your VPC). For short exploration sessions the cost is negligible. The variable
is still exposed so a user can set `ipam_tier = "free"` if they want to
explore the limitations themselves.

**Lesson learned:** Module defaults and composition defaults serve different
purposes. The module defaults to "free" because it is the safest assumption
for an unknown consumer. The composition defaults to "advanced" because it
knows it needs private scopes. The composition overrides the module's default
based on its specific requirements -- this is exactly what the composition
layer is for.

**Cost Implication:** The advanced tier costs money. Users should run
`terraform destroy` when done exploring. See Decision 12 about destroy times.

---

## 7. cascade_delete = true Everywhere

**Decision:** Every pool and the IPAM instance itself set
`cascade_delete = true`.

**Rationale:** The aws-ipam and aws-ipam-pool modules both default
`cascade_delete` to `false` for safety (see Decision 5 in both modules'
decisions.md). In production, this is the right default -- a `terraform
destroy` should fail rather than silently cascade-delete pools that may have
active VPC allocations.

This composition overrides the default because it is an exploration
environment, not production infrastructure. The priority is clean teardown:

- Without `cascade_delete = true`, `terraform destroy` would fail because the
  environment pool has an active allocation (the VPC's CIDR). The user would
  need to destroy the VPC first, then the environment pool, then the regional
  pool, then the top-level pool, then the IPAM -- in that exact order.
- With `cascade_delete = true`, `terraform destroy` handles the entire
  hierarchy in one command. Terraform still destroys in dependency order (VPC
  first, then pools bottom-up), but if something gets stuck, AWS cleans up
  the children.

This is another example of the composition layer overriding module defaults
based on context. The same module used in a production composition would keep
`cascade_delete = false`.

**Security Implication:** In an exploration context, the risk of accidental
deletion is low and the cost of manual cleanup is high. In production, the
calculus inverts: the risk of accidental deletion is high and manual cleanup
is the correct safeguard. The composition makes the appropriate choice for its
context.

---

## 8. Flow Logs Disabled by Default

**Decision:** `var.flow_log_enabled` defaults to `false`, overriding the
aws-vpc module's default of `true`.

**Rationale:** The aws-vpc module enables flow logs by default because network
visibility is a security best practice (see Decision 4 in aws-vpc's
decisions.md). This composition disables them because:

1. The composition's purpose is IPAM exploration, not network traffic analysis.
   Flow logs add resources (CloudWatch log group, IAM role) that are irrelevant
   to the learning objective.
2. Flow logs incur CloudWatch Logs costs for ingestion and storage. For an
   exploration VPC with no workloads, this is pure waste.
3. The VPC created by this composition has no subnets, no EC2 instances, and no
   network interfaces. Flow logs would capture nothing useful.

The variable is exposed so a user can set `flow_log_enabled = true` if they
want to explore the flow log + IPAM interaction.

---

## 9. Provider default_tags for Managed-By

**Decision:** The provider block sets `default_tags` with
`Managed-By = Terraform`.

```hcl
provider "aws" {
  default_tags {
    tags = {
      Managed-By = "Terraform"
    }
  }
}
```

**Rationale:** `default_tags` at the provider level applies tags to every
resource created by every module in the composition -- including resources
internal to modules that do not propagate `var.tags`. This is important because:

1. Some resources are created deep inside modules (e.g., the IAM role for flow
   logs in the aws-vpc module). These resources may not receive `var.tags`
   depending on the module's implementation.
2. `Managed-By = Terraform` is a signal to anyone browsing the AWS console
   that they should not modify the resource manually. Without this tag,
   someone might edit a pool or VPC directly in the console, creating drift.
3. Provider-level tags and module-level tags merge automatically. If a module
   also sets `Managed-By` in its own tags, the module's value takes precedence
   (Terraform's last-writer-wins for tag merging within `default_tags` +
   resource tags).

Module-level tags (`Composition`, `Environment`, `Project`) are passed via
`local.tags` to each module's `tags` variable. These provide organizational
context. The `Managed-By` tag provides tool context.

**Alternatives Considered:** Putting `Managed-By` in `local.tags` instead of
`default_tags`. This would work for resources that receive the `tags` variable,
but would miss any resource that the module creates internally without
propagating tags. Provider-level `default_tags` is the only way to guarantee
every resource is tagged.

---

## 10. Locale Precondition Added to aws-ipam-pool Module

**Decision:** A precondition was added to the aws-ipam-pool module during
this composition's development:

```hcl
lifecycle {
  precondition {
    condition     = var.source_ipam_pool_id == null || var.locale != null
    error_message = "locale is required for child pools (when source_ipam_pool_id is set). Set locale to the AWS region where allocations from this pool will be used."
  }
}
```

**Rationale:** The user hit a cryptic AWS error during the first apply:

> The resource type vpc is not valid for pool with None locale.

This error appeared when the VPC tried to allocate from a pool that had
`source_ipam_pool_id` set (making it a child pool) but no `locale`. AWS
requires child pools to have a locale -- allocations must target a specific
region. But the error message does not explain this. It says "vpc is not valid
for pool" which sounds like a resource type problem, not a missing locale
problem.

The precondition catches this at `terraform plan` time with a clear message:
"locale is required when source_ipam_pool_id is set." The user never sees the
cryptic AWS error.

The fix was applied to the aws-ipam-pool module (not the composition) because
this is a universal constraint: ANY child pool needs a locale, regardless of
which composition uses it. The module should enforce its own invariants.

**Lesson learned:** When AWS returns a confusing error, the right response
is not to document the workaround -- it is to add a precondition to the module
so no one ever hits that error again. Preconditions are the module's contract
with its consumers. This follows the pattern established in aws-ipam (Decision
6, tier-gating preconditions) and aws-ipam-pool (Decision 10, six lifecycle
preconditions).

---

## 11. pool_id Output depends_on Fix

**Decision:** The `pool_id` output in the aws-ipam-pool module was changed
to include an explicit `depends_on`:

```hcl
output "pool_id" {
  description = "The ID of the IPAM pool."
  value       = aws_vpc_ipam_pool.this.id
  depends_on  = [aws_vpc_ipam_pool_cidr.this]
}
```

**Rationale:** The user hit this error during apply:

> The allocation size is too big for the pool.

The error was misleading. The pool had a `/14` CIDR, and the VPC was requesting
a `/20` -- which easily fits. The real issue was a race condition in
Terraform's dependency graph.

Here is what happened:

1. Terraform creates `aws_vpc_ipam_pool.this` (the pool resource).
2. The `pool_id` output reads `aws_vpc_ipam_pool.this.id` -- this is available
   as soon as the pool is created, before its CIDRs are provisioned.
3. The downstream VPC module receives `pool_id` and starts creating the VPC
   with `ipv4_ipam_pool_id = <pool_id>`.
4. Meanwhile, `aws_vpc_ipam_pool_cidr.this` (the CIDR provisioning) is still
   running in parallel.
5. The VPC tries to allocate from a pool that has no provisioned CIDRs yet.
   AWS rejects the allocation with "allocation size is too big" because the
   pool's available space is zero.

The fix adds `depends_on = [aws_vpc_ipam_pool_cidr.this]` to the `pool_id`
output. This tells Terraform: "do not consider this output ready until the
CIDR is also provisioned." The downstream VPC module will not start until both
the pool AND its CIDRs are complete.

**Key Terraform behavior:** Terraform does NOT wait for all resources in a
module to complete before exposing outputs. It follows the dependency graph
precisely. An output that references `resource_A.id` does not implicitly
depend on `resource_B` just because they are in the same module. If there is
no explicit reference or `depends_on`, Terraform assumes the output is ready
as soon as its direct dependencies are met.

This is a critical insight for module design: when a module creates a
"compound resource" (a pool + its CIDRs, a VPC + its flow logs), outputs that
consumers will use to build dependent resources must `depends_on` ALL the
pieces that need to be ready, not just the piece whose ID they return.

**Lesson learned:** When Terraform produces an error that contradicts visible
state (a `/20` does not fit in a `/14`?), the issue is usually a race condition
-- resources executing in an order the module author did not anticipate.
`depends_on` on outputs is the correct fix for inter-module race conditions.

The fix was applied to the aws-ipam-pool module (not the composition) because
the pool is not "ready" until its CIDRs are provisioned, regardless of which
composition uses it.

---

## 12. Destroy Takes 5-10+ Minutes

**Decision:** This is not a code decision but an operational learning worth
recording. The composition's `terraform destroy` takes significantly longer
than a typical Terraform destroy.

**Rationale:** IPAM CIDR deallocation propagates through the pool hierarchy
asynchronously. When Terraform destroys the VPC, IPAM begins deallocating the
`/20` from the environment pool. This deallocation must propagate up through
the regional pool and top-level pool before each tier can be destroyed.

The 3-tier hierarchy (Decision 3) makes this slower because there are more
levels of propagation. In one session, the destroy exceeded 14 minutes. The
VPC was already gone from AWS (confirmed in the console), but Terraform was
still waiting for pool CIDR deprovisioning to complete.

When the destroy appeared stuck, the user pressed Ctrl+C and re-ran
`terraform destroy`. On the second run, the deprovisioning had progressed far
enough that the remaining resources were cleaned up quickly.

**Operational guidance:**
- Do not panic if destroy takes a long time. This is normal AWS behavior.
- If destroy exceeds 15 minutes, Ctrl+C and re-run. The state file tracks
  what has already been destroyed.
- The destroy order is: VPC first, then environment pool, regional pool,
  top-level pool, and finally the IPAM instance. Each waits for its CIDRs
  to fully deprovision.
- `cascade_delete = true` (Decision 7) helps here: AWS will clean up child
  CIDRs even if Terraform's ordering gets interrupted.

**Lesson learned:** Infrastructure provisioning and deprovisioning are not
symmetric in time. Creating the entire stack takes ~2 minutes. Destroying it
takes 5-14 minutes because CIDR deallocation propagates asynchronously through
the pool hierarchy on the AWS side, and Terraform must wait synchronously at
each tier for it to complete. Budget time for cleanup accordingly.

---

## 13. Module Renames During Refactor

**Decision:** Module labels were renamed during a refactor to be generic
rather than region/environment-specific:

| Before | After |
|--------|-------|
| `module "us_west_2_pool"` | `module "regional_pool"` |
| `module "us_west_2_production_pool"` | `module "environment_pool"` |
| `module "test_vpc"` | `module "vpc"` |

**Rationale:** The original names baked specific values into module labels:
`us_west_2` and `production`. When `aws_region` and `environment` became
variables (not hardcoded), the module labels became misleading. Deploying to
`us-east-1` with a module named `us_west_2_pool` would confuse anyone reading
the state file or plan output.

The new names describe the role in the hierarchy (`regional_pool`,
`environment_pool`, `vpc`), not the specific deployment. The region and
environment are captured in the resource names via `locals.tf`:

```hcl
region_pool   = "${var.project_name}-${local.region_short}"        # e.g. "lab-usw2"
env_pool_name = "${var.project_name}-${local.region_short}-${var.environment}"  # e.g. "lab-usw2-production"
```

**State migration:** Renaming module labels changes the Terraform resource
addresses. This required `terraform state mv` commands:

```bash
terraform state mv 'module.us_west_2_pool' 'module.regional_pool'
terraform state mv 'module.us_west_2_production_pool' 'module.environment_pool'
terraform state mv 'module.test_vpc' 'module.vpc'
```

Without `state mv`, Terraform would plan to destroy all resources under the
old names and recreate them under the new names -- a destructive operation that
would break the IPAM hierarchy (CIDRs would be deallocated and reallocated,
potentially getting different address ranges).

**Lesson learned:** Module labels are part of the Terraform state address.
Renaming them is a refactor that requires `state mv` to avoid destroy/recreate
cycles. Choose generic, role-based names from the start to avoid this problem.
Specific values (region, environment) belong in resource names and tags, not
module labels.
