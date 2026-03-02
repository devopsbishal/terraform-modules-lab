# Design Decisions: AWS IPAM Pool Module

Captures the "why" behind every significant design choice made during the
module's creation, review, and fix process. Each section records the decision,
the rationale, alternatives that were discussed, and any security or
operational implications.

This document serves as the learning artifact for the module -- someone reading
it should understand not just WHAT the module does, but WHY every choice was
made, and what tradeoffs were weighed.

---

## Table of Contents

**Architecture & Scope**
1. [Pool + CIDRs in One Module](#1-pool--cidrs-in-one-module)
2. [Allocations Excluded from This Module](#2-allocations-excluded-from-this-module)
3. [One Pool per Module Call](#3-one-pool-per-module-call)

**The Big Fix: CIDR Key Stability**
4. [cidrs Changed from List to Map](#4-cidrs-changed-from-list-to-map)

**Resource Defaults**
5. [address_family Defaults to "ipv4"](#5-address_family-defaults-to-ipv4)
6. [cascade_delete Defaults to False](#6-cascade_delete-defaults-to-false)
7. [auto_import Defaults to False](#7-auto_import-defaults-to-false)
8. [locale Defaults to Null](#8-locale-defaults-to-null)
9. [Allocation Guardrails Default to Null](#9-allocation-guardrails-default-to-null)

**Validation & Precondition Decisions**
10. [Six Lifecycle Preconditions for Cross-Variable Constraints](#10-six-lifecycle-preconditions-for-cross-variable-constraints)
11. [nullable = false on Map Variables](#11-nullable--false-on-map-variables)
12. [Variable Ordering Fix: public_ip_source before publicly_advertisable](#12-variable-ordering-fix-public_ip_source-before-publicly_advertisable)

**What Was Deferred**
13. [source_resource Block Not Exposed](#13-source_resource-block-not-exposed)
14. [cidr_authorization_context Not Exposed](#14-cidr_authorization_context-not-exposed)

**Testing Insights**
15. [All Tests Passed on First Run](#15-all-tests-passed-on-first-run)
16. [Computed Attribute Limitation for netmask_length CIDRs](#16-computed-attribute-limitation-for-netmask_length-cidrs)

---

## 1. Pool + CIDRs in One Module

**Decision:** `aws_vpc_ipam_pool` and `aws_vpc_ipam_pool_cidr` are managed in
the same module. A pool and its CIDRs are created, updated, and destroyed
together.

**Rationale:** A pool without provisioned CIDRs is incomplete -- nothing can
allocate from it. CIDRs cannot exist without a pool. They share a lifecycle
unconditionally: you never want a CIDR managed independently of the pool it
belongs to, and you never want a pool existing without its CIDR configuration.

This follows the "subordinate resource" pattern established in the aws-vpc
module, where the flow log IAM role stays in the VPC module because it exists
solely to support VPC flow logs. The same principle applies here: pool CIDRs
exist solely to populate the pool.

The module boundary test from `module_design.md` confirms this:
- **Single responsibility:** Both resources serve one purpose -- "provide a
  pool of IP addresses." Separating them does not create two meaningful
  responsibilities.
- **Lifecycle:** CIDRs change when the pool's address space changes -- they
  do not have an independent lifecycle.
- **Reusability:** No one needs a standalone "CIDR provisioner" module.
- **Blast radius:** Combining them does not expand the blast radius because
  changing a CIDR inherently affects the pool.

**Alternatives Considered:** A separate `aws-ipam-pool-cidr` module. Rejected
because it would force every consumer to wire two modules together for the most
basic operation (create a pool with addresses). The module interface would also
be awkward: the CIDR module would need `pool_id` as input, creating an
artificial dependency chain with no benefit.

---

## 2. Allocations Excluded from This Module

**Decision:** `aws_vpc_ipam_pool_cidr_allocation` resources are not managed by
this module. They belong at the composition or VPC level.

**Rationale:** An allocation connects two independently managed resources: a
pool (managed by the networking team) and a VPC (managed by the application
team or a composition). Including allocations in the pool module would create
a coupling problem:

```hcl
# This would be wrong -- the pool module should not know about VPCs
module "pool" {
  source = "../aws-ipam-pool"
  vpc_ids = [module.vpc.vpc_id]  # Circular: pool needs VPC, VPC needs pool
}
```

Allocations are the composition layer's job:

```hcl
module "pool" { source = "../aws-ipam-pool" }
module "vpc"  { source = "../aws-vpc" }

resource "aws_vpc_ipam_pool_cidr_allocation" "this" {
  ipam_pool_id = module.pool.pool_id
  cidr         = module.vpc.vpc_cidr_block
}
```

In Phase 3 (VPC integration), the aws-vpc module itself may gain an optional
`ipam_pool_id` variable to allocate its CIDR from a pool, further confirming
that allocations do not belong in the pool module.

This mirrors Decision 2 in the parent aws-ipam module's decisions.md: the
allocation concern crosses module boundaries and must live in the composition.

---

## 3. One Pool per Module Call

**Decision:** The module creates exactly one IPAM pool. Hierarchies (top-level
pool with regional sub-pools) are built by calling the module multiple times,
connecting them via `pool_id` and `source_ipam_pool_id`.

**Rationale:** A typical IPAM hierarchy looks like this:

```
Global pool (10.0.0.0/8)
  +-- us-east-1 pool (10.0.0.0/12)
  +-- eu-west-1 pool (10.16.0.0/12)
       +-- production pool (10.16.0.0/14)
       +-- development pool (10.16.4.0/14)
```

Each level has different configuration: different locales, different allocation
guardrails, different tags. A single module trying to represent this tree
would need deeply nested variable objects:

```hcl
# This would be unmaintainable
pools = {
  global = {
    cidr = "10.0.0.0/8"
    children = {
      us-east-1 = {
        locale = "us-east-1"
        cidr = "10.0.0.0/12"
        children = { ... }
      }
    }
  }
}
```

With one pool per call, the composition is flat and explicit:

```hcl
module "global_pool" {
  source        = "../aws-ipam-pool"
  name          = "global"
  ipam_scope_id = module.ipam.private_default_scope_id
  cidrs         = { rfc1918 = { cidr = "10.0.0.0/8" } }
}

module "us_east_1_pool" {
  source              = "../aws-ipam-pool"
  name                = "us-east-1"
  ipam_scope_id       = module.ipam.private_default_scope_id
  source_ipam_pool_id = module.global_pool.pool_id
  locale              = "us-east-1"
  cidrs               = { main = { netmask_length = 12 } }
}
```

The `pool_id` output feeds directly into `source_ipam_pool_id` on the next
call. This is the same composability pattern used throughout the project:
outputs feed inputs, modules are independent, the composition layer decides
how they connect.

**Alternatives Considered:** A hierarchical module with recursive pool
definitions. Rejected because (1) Terraform does not natively support
recursive types, so the variable definition would be awkward, (2) debugging
plan output for a tree of pools in a single module call is much harder than
debugging separate module calls, and (3) individual pools can be targeted with
`-target` in emergencies if they are separate module calls.

---

## 4. cidrs Changed from List to Map

**Decision:** The `cidrs` variable was changed from `list(object({...}))` to
`map(object({...}))` during the review process. This was the most impactful
finding in the review.

**Rationale: The Index Stability Problem**

The original code used a list with a computed `for_each` key:

```hcl
# BEFORE (dangerous)
variable "cidrs" {
  type = list(object({
    cidr           = optional(string)
    netmask_length = optional(number)
  }))
}

resource "aws_vpc_ipam_pool_cidr" "this" {
  for_each = {
    for idx, cidr in var.cidrs :
    coalesce(cidr.cidr, "netmask-${cidr.netmask_length}-${idx}") => cidr
  }
  # ...
}
```

For explicit CIDRs, the key is the CIDR string itself (e.g., `"10.0.0.0/8"`)
-- stable and safe. But for `netmask_length` entries where the CIDR is
assigned by IPAM at apply time, the key includes the list index:
`"netmask-24-0"`, `"netmask-16-1"`.

If a user removes the first entry from the list:

```hcl
# Before: two entries
cidrs = [
  { netmask_length = 24 },  # key: "netmask-24-0"
  { netmask_length = 16 },  # key: "netmask-16-1"
]

# After: first entry removed
cidrs = [
  { netmask_length = 16 },  # key: "netmask-16-0" (was "netmask-16-1")
]
```

Terraform sees `"netmask-16-1"` being destroyed and `"netmask-16-0"` being
created. It will destroy and recreate the CIDR allocation, meaning the pool
temporarily loses that address space. Any VPCs with allocations from that
CIDR would be disrupted.

**The Fix: User-Provided Keys**

```hcl
# AFTER (safe)
variable "cidrs" {
  type = map(object({
    cidr           = optional(string)
    netmask_length = optional(number)
  }))
}

resource "aws_vpc_ipam_pool_cidr" "this" {
  for_each = var.cidrs
  # ...
}
```

Now the user provides stable keys:

```hcl
cidrs = {
  prod-24 = { netmask_length = 24 }
  dev-16  = { netmask_length = 16 }
}
```

Removing `prod-24` only destroys that specific CIDR. The `dev-16` key is
unchanged, so its resource is untouched. The map keys are the Terraform
resource instance keys, fully under user control.

**Key Terraform behavior:** `for_each` tracks resources by their key in the
state file. When a key changes, Terraform treats it as a destroy + create, not
an update. For stateful infrastructure like CIDR allocations, this distinction
is critical. Index-based keys are inherently unstable because they depend on
the position of items in a list, not their identity.

This matches the `custom_scopes` pattern in the parent aws-ipam module, which
uses `map(string)` with user-provided keys for the same reason.

**Alternatives Considered:** (1) Using `netmask_length` alone as the key
(`"netmask-24"`, `"netmask-16"`). This works only if you never have two
entries with the same `netmask_length`, which is a fragile assumption. Two
`/24` allocations from the same pool is a valid use case. (2) Adding a `key`
field to the list objects. This gives stable keys but the list type still
invites ordering-sensitive thinking. The map type makes the key a first-class
concept and is the idiomatic Terraform pattern.

**Security Implication:** Prevents accidental destruction and recreation of
IP address allocations in production. CIDR churning could disrupt VPCs,
break DNS resolution, and cause connectivity outages.

---

## 5. address_family Defaults to "ipv4"

**Decision:** `var.address_family` defaults to `"ipv4"` rather than being
required.

**Rationale:** The vast majority of IPAM pools are IPv4. Making IPv4 the
default reduces boilerplate for the common case:

```hcl
# Common case: no need to specify address_family
module "pool" {
  source        = "../aws-ipam-pool"
  name          = "production"
  ipam_scope_id = module.ipam.private_default_scope_id
  cidrs         = { main = { cidr = "10.0.0.0/16" } }
}

# Uncommon case: explicitly opt into IPv6
module "ipv6_pool" {
  source         = "../aws-ipam-pool"
  name           = "production-ipv6"
  address_family = "ipv6"
  ipam_scope_id  = module.ipam.private_default_scope_id
  cidrs          = { main = { cidr = "2001:db8::/32" } }
}
```

The `nullable = false` on this variable ensures it cannot be set to `null` to
bypass the validation block.

**Alternatives Considered:** Making `address_family` required (no default).
This would force every caller to write `address_family = "ipv4"` even for
IPv4-only environments. Rejected as unnecessary friction.

---

## 6. cascade_delete Defaults to False

**Decision:** `var.cascade_delete` defaults to `false`. This is consistent
with the parent aws-ipam module (Decision 5 in its decisions.md).

**Rationale:** When `cascade = true`, destroying the pool also destroys all
CIDRs and allocations within it -- including allocations that may be in use
by production VPCs. With `cascade = false` (the default), Terraform refuses
to destroy a pool that has active allocations. The operator must explicitly
clean up allocations first, or consciously set `cascade_delete = true`.

The variable is named `cascade_delete` rather than the API argument name
`cascade`. The longer name is more descriptive -- `cascade` alone is
ambiguous (cascade what?), while `cascade_delete` clearly communicates the
destructive intent. This naming is consistent with the parent module.

**Security Implication:** Prevents accidental destruction of IP address
allocations in production. A `terraform destroy` on a pool module will fail
with a clear AWS error rather than silently removing active allocations.

---

## 7. auto_import Defaults to False

**Decision:** `var.auto_import` defaults to `false`.

**Rationale:** When `auto_import = true`, IPAM automatically claims any VPC
in the scope whose CIDR falls within the pool's range. This is dangerous as a
default because it could silently affect VPCs the user did not intend to
manage.

Consider a user who creates a pool with `10.0.0.0/8` and `auto_import = true`.
Every existing VPC in any 10.x.x.x range in the account is immediately pulled
into IPAM management. If the user was not expecting this, it can disrupt
existing workflows that relied on manual IP management.

Defaulting to `false` means VPC-to-pool relationships must be established
explicitly (via allocations at the composition level), which is the safer,
more predictable pattern.

**Alternatives Considered:** Defaulting to `true` to enable the "hands-off"
IPAM experience. Rejected because the side effects are invisible and
potentially disruptive. Explicit is better than implicit for infrastructure
management.

---

## 8. locale Defaults to Null

**Decision:** `var.locale` defaults to `null`, meaning the pool is a top-level
pool that spans all IPAM operating regions.

**Rationale:** IPAM pools come in two flavors:
1. **Top-level pools** (`locale = null`): Hold the master CIDR space. VPCs
   cannot allocate directly from them.
2. **Regional pools** (`locale = "us-east-1"`): Child pools pinned to a
   specific region. VPCs allocate from these.

Both are valid, common configurations. Defaulting to `null` lets the same
module serve both roles:

```hcl
# Top-level pool: no locale
module "global" {
  source = "../aws-ipam-pool"
  # locale is null (default)
}

# Regional pool: explicit locale
module "regional" {
  source              = "../aws-ipam-pool"
  source_ipam_pool_id = module.global.pool_id
  locale              = "us-east-1"
}
```

If `locale` were required, the user would need to pass `locale = null`
explicitly for top-level pools, which is awkward. If it defaulted to a
specific region, the module would make assumptions about the user's
deployment topology.

**Alternatives Considered:** (1) Defaulting to `data.aws_region.current.name`
to auto-detect the region. Rejected because it would make every pool a
regional pool by default, which breaks the top-level pool use case. It would
also require a data source, adding a dependency and slowing plan time.
(2) Making locale required. Rejected because top-level pools genuinely have
no locale.

---

## 9. Allocation Guardrails Default to Null

**Decision:** `allocation_min_netmask_length`, `allocation_max_netmask_length`,
and `allocation_default_netmask_length` all default to `null` (no guardrails).

**Rationale:** Opinionated defaults would need to be address-family-specific.
A sensible default for IPv4 (e.g., min=/16, max=/28) would be wrong for IPv6
(where /48 and /64 are standard allocations). Since `address_family` can be
either `"ipv4"` or `"ipv6"`, any hardcoded netmask default would be incorrect
for one family.

Defaulting to `null` means no guardrails are enforced by default -- any valid
netmask can be requested. This puts the burden on the user to configure
guardrails appropriate to their address family and organizational policies.

The reviewer confirmed this decision during the review discussion. The
alternative -- IPv4-specific defaults with conditional logic -- was considered
and rejected because it adds complexity for a questionable benefit. Users who
care about allocation guardrails will configure them explicitly.

**Alternatives Considered:** (1) Family-specific defaults using a conditional:
`default = var.address_family == "ipv4" ? 16 : 48`. Rejected because Terraform
variable defaults cannot reference other variables. (2) A locals-based
approach that sets guardrails when not provided. Rejected because it hides
behavior -- the user would not know guardrails were active unless they read
locals.tf.

---

## 10. Six Lifecycle Preconditions for Cross-Variable Constraints

**Decision:** The `aws_vpc_ipam_pool.this` resource has six
`lifecycle { precondition }` blocks that validate relationships between
variables. Four were included in the original module; two were added during
review.

**The original four preconditions:**

1. **publicly_advertisable requires IPv6:** `publicly_advertisable == false ||
   address_family == "ipv6"`. Public IP advertisement is an IPv6-only feature
   in AWS.

2. **public_ip_source requires IPv4:** `public_ip_source == null ||
   address_family == "ipv4"`. The public IP source setting applies only to
   IPv4 pools in public scopes.

3. **min <= max netmask:** `allocation_min_netmask_length <=
   allocation_max_netmask_length`. A minimum larger than the maximum is
   contradictory and would make all allocations impossible.

4. **default netmask within min/max range:**
   `allocation_default_netmask_length` must be between min and max (inclusive).
   Without this check, the default would be rejected by the guardrails at
   allocation time, producing a confusing error.

**The two preconditions added during review:**

5. **IPv4 netmask lengths capped at 32:** When `address_family = "ipv4"`, all
   netmask lengths (min, max, default, and `cidrs[*].netmask_length`) must be
   <= 32. The individual variable validations accept 0-128 (the full IPv6
   range) because validation blocks cannot reference `address_family`. This
   precondition catches the cross-variable case with a clear error instead of
   a cryptic AWS API rejection.

6. **CIDR-to-address-family match:** Each explicit CIDR in the `cidrs` map
   must match the pool's `address_family`. IPv6 addresses contain colons;
   IPv4 addresses do not. The detection is:
   ```hcl
   var.address_family == "ipv4" ? !can(regex(":", c.cidr)) : can(regex(":", c.cidr))
   ```
   Without this, a user could add `10.0.0.0/8` to an IPv6 pool. The AWS API
   would reject it, but with a less helpful error message than the
   precondition provides.

**Why preconditions instead of variable validation blocks:** Terraform's
`validation` block on a variable can only reference that one variable. All six
constraints reference at least two variables. `lifecycle { precondition }` is
the only mechanism for cross-variable validation.

**Key Terraform behavior:** Preconditions fire during `terraform plan`, before
any resources are created or modified. They produce errors that name the
specific constraint, unlike AWS API errors which fire at apply time and are
often opaque. This is why preconditions are preferred over "let the API
reject it."

**Why variable-level validation still exists alongside preconditions:** The
variable-level validations (e.g., netmask 0-128, CIDR format via
`cidrhost()`) catch single-variable errors immediately. Preconditions catch
cross-variable errors. Together they form a layered validation strategy:
variable validations are the first line of defense (fastest feedback),
preconditions are the second (catch relationships).

---

## 11. nullable = false on Map Variables

**Decision:** `nullable = false` was added to `allocation_resource_tags` and
`tags` during the review. Both have `default = {}`.

**Rationale:** Without `nullable = false`, a caller can pass
`tags = null`. Terraform accepts this, skips the default value, and passes
`null` to `locals.tf` where `merge()` receives `null` as an argument:

```hcl
# locals.tf
locals {
  tags = merge(
    { Name = var.name },
    var.tags  # null here crashes merge()
  )
}
```

The error message from `merge()` receiving null is not helpful -- it
references the local expression, not the variable that caused the problem.
Adding `nullable = false` catches the error at the variable level with a
clear message: "This variable does not accept null values."

This extends the `nullable = false` pattern from the parent aws-ipam module
(Decision 11), where it was applied to five variables. The IPAM pool module
applies it to all variables that have defaults and should not accept null:
`address_family`, `auto_import`, `cascade_delete`, `cidrs`, `description`,
`name`, `ipam_scope_id`, `publicly_advertisable`, `allocation_resource_tags`,
and `tags`.

**Key Terraform behavior:** When a variable is nullable (the default) and
receives `null`, Terraform skips all `validation` blocks AND substitutes
`null` for the default value. This double bypass is why `nullable = false` is
essential for variables with safe defaults.

---

## 12. Variable Ordering Fix: public_ip_source before publicly_advertisable

**Decision:** The declaration order of `public_ip_source` and
`publicly_advertisable` was swapped in `variables.tf` during the review.

**Rationale:** Project coding conventions require variables to be in
alphabetical order. `public_ip_source` (public_i...) sorts before
`publicly_advertisable` (publicly...). The original order had them reversed.

This is a mechanical convention, but it matters for consistency. Every other
module in the project follows alphabetical ordering. When a developer looks
for a variable, they expect to find it in its alphabetical position. The
parent aws-ipam module, the aws-vpc module, and this module all follow the
same rule.

The resource arguments in `main.tf` were already in correct alphabetical
order and did not need changes.

---

## 13. source_resource Block Not Exposed

**Decision:** The `aws_vpc_ipam_pool` resource supports a `source_resource`
block for resource planning pools. This is not exposed by the module. A
comment in `main.tf` documents the omission.

**Rationale:** Resource planning pools track the CIDR usage of an existing
VPC without actually managing its addresses. This is a niche feature for
organizations that want IPAM visibility into legacy VPCs without migrating
them to IPAM-managed addressing.

Exposing `source_resource` would add a variable with a nested object type
(resource type, resource ID, resource region) for a feature that most users
will not need. The comment ensures the feature is discoverable for future
implementers:

```hcl
# Note: The source_resource block (for resource planning pools that track
# usage of an existing VPC's CIDR space) is not yet exposed by this module.
# Add it when resource planning pool support is needed.
```

This follows the same deferral pattern used in the parent aws-ipam module for
OU exclusion on resource discovery (Decision 15 in its decisions.md).

**Revisit when:** A user needs to create resource planning pools for IPAM
visibility into existing VPCs.

---

## 14. cidr_authorization_context Not Exposed

**Decision:** The `aws_vpc_ipam_pool_cidr` resource supports a
`cidr_authorization_context` block for BYOIP (Bring Your Own IP) ownership
verification. This is not exposed by the module. A comment in `main.tf`
documents the omission.

**Rationale:** BYOIP requires an external workflow: the user must create an
RDAP record for their IP range, generate a self-signed X.509 certificate,
sign an authorization message, and provide the message + signature to AWS.
This workflow happens outside Terraform and produces two values (`message`
and `signature`) that would be passed into the module.

The feature is deferred because:
1. BYOIP is uncommon -- most organizations use AWS-provided IP space.
2. The authorization context is typically a one-time operation during initial
   BYOIP setup, not a recurring Terraform concern.
3. Including it would add variables that are irrelevant to 95% of users.

```hcl
# Note: The cidr_authorization_context block (message + signature for BYOIP
# ownership verification) is not yet exposed by this module. Add it when
# Bring Your Own IP (BYOIP) pool support is needed.
```

**Revisit when:** A user needs to provision BYOIP CIDRs into an IPAM pool.

---

## 15. All Tests Passed on First Run

**Decision:** This is not a code decision but a process observation worth
recording. Unlike the parent aws-ipam module (which had 2 bugs caught by
tests -- Decisions 18 and 19 in its decisions.md), the aws-ipam-pool module's
tests all passed on the first run.

**Rationale:** The review-then-test workflow caught issues before tests were
written. The CIDR key stability fix (Decision 4), the variable ordering fix
(Decision 12), the nullable additions (Decision 11), and the precondition
additions (Decision 10, items 5 and 6) were all identified during code review
and applied before the test writer generated tests. The tests validated the
corrected code, not the original code.

**Lesson learned:** Thorough review reduces test-discovered bugs. Tests are
still essential (they catch things review misses, like the GovCloud regex in
the parent module), but a careful review pass eliminates the most obvious
defects before tests are written. This is the intended workflow: tf-reviewer
identifies structural and logical issues, tf-test-writer verifies the
corrected module.

---

## 16. Computed Attribute Limitation for netmask_length CIDRs

**Decision:** The `pool_cidrs` output returns a map of user-provided keys to
provisioned CIDR blocks. For `netmask_length` entries, the CIDR value is
computed by IPAM at apply time and is not known during plan.

**Rationale:** When a CIDR is provisioned by `netmask_length` (rather than an
explicit CIDR string), IPAM assigns a CIDR from the parent pool's available
space. This happens during `terraform apply`, not `terraform plan`. This means:

1. Plan-mode tests (`command = plan`) cannot assert on the actual CIDR value
   for `netmask_length` entries. They can verify the key exists in the output
   map but not the value.

2. Integration tests (`command = apply` against real AWS) would be needed to
   verify that IPAM assigns CIDRs correctly and that the output map contains
   the expected values.

3. The `pool_cidrs` output description was updated during review to clearly
   state this: "For netmask_length allocations, the value is the CIDR
   assigned by IPAM."

This is an inherent limitation of plan-mode testing for resources with
computed attributes -- not a module defect. The module correctly exposes the
computed value; it simply is not available until apply time.

**Alternatives Considered:** Not including `netmask_length` CIDRs in the
output map. Rejected because the assigned CIDR is essential information for
downstream modules (e.g., a composition that logs the assigned address ranges).
