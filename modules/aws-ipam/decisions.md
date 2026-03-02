# Design Decisions: AWS IPAM Module

Captures the "why" behind every significant design choice made during the
module's creation, review, and bug-fix process. Each section records the
decision, the rationale, alternatives that were discussed, and any security
or cost implications.

This document serves as the learning artifact for the module -- someone reading
it should understand not just WHAT the module does, but WHY every choice was
made, and what tradeoffs were weighed.

---

## Table of Contents

**Architecture & Scope**
1. [Two-Module Split: aws-ipam + aws-ipam-pool](#1-two-module-split-aws-ipam--aws-ipam-pool)
2. [Allocations Belong at Composition Level](#2-allocations-belong-at-composition-level)
3. [Phased Approach to IPAM Adoption](#3-phased-approach-to-ipam-adoption)

**Resource Decisions**
4. [Tier Defaults to "free"](#4-tier-defaults-to-free)
5. [Cascade Delete Defaults to False](#5-cascade-delete-defaults-to-false)
6. [Tier-Gating Preconditions](#6-tier-gating-preconditions)
7. [Organizations Resources Included but Optional](#7-organizations-resources-included-but-optional)
8. [Resource Discovery Regions Fall Back to IPAM Regions](#8-resource-discovery-regions-fall-back-to-ipam-regions)
9. [Custom Scopes via map(string)](#9-custom-scopes-via-mapstring)
10. [Delegated Admin as Nullable String](#10-delegated-admin-as-nullable-string)

**Variable & Validation Decisions**
11. [nullable = false on Key Variables](#11-nullable--false-on-key-variables)
12. [Custom Scope Descriptions Must Be Non-Empty](#12-custom-scope-descriptions-must-be-non-empty)
13. [GovCloud Region Regex Fix](#13-govcloud-region-regex-fix)

**What Was Removed**
14. [metered_account Variable Removed](#14-metered_account-variable-removed)

**What Was Deferred**
15. [OU Exclusion on Resource Discovery](#15-ou-exclusion-on-resource-discovery)
16. [External Resource Discovery Association](#16-external-resource-discovery-association)
17. [Integration Tests Deferred](#17-integration-tests-deferred)

**Bugs Found by Tests**
18. [custom_scope_types Output Used Wrong Attribute](#18-custom_scope_types-output-used-wrong-attribute)
19. [GovCloud Region Regex Broke on us-gov-west-1](#19-govcloud-region-regex-broke-on-us-gov-west-1)

---

## 1. Two-Module Split: aws-ipam + aws-ipam-pool

**Decision:** IPAM management is split across two modules: `aws-ipam` (this
module) manages the IPAM instance, scopes, delegated admin, and resource
discovery. A separate `aws-ipam-pool` module (Phase 2) will manage pools and
CIDR provisioning.

**Rationale:** IPAM instances and pools have fundamentally different lifecycles.
An IPAM instance is created once per organization or account and rarely
changes. Pools are created per team, per environment, or per region and change
frequently as the organization grows. Bundling them would mean that adding a
new pool to a team's configuration would trigger a plan that also touches the
IPAM instance -- expanding the blast radius of a routine operation.

The module boundary test from `module_design.md` confirms the split:
- **Single responsibility:** IPAM instance setup vs. address pool management
  are two distinct concerns.
- **Lifecycle:** IPAM instance is "create once, rarely modify." Pools are
  "create many, modify often."
- **Reusability:** Multiple pool modules reference one IPAM instance. Bundling
  would force consumers to use a single monolithic module for everything.
- **Blast radius:** A misconfigured pool change should not risk the IPAM
  instance or its Organizations delegation.

The two modules connect via outputs: `aws-ipam` exports `ipam_id`,
`private_default_scope_id`, `public_default_scope_id`, and `custom_scope_ids`,
which the pool module consumes as inputs.

**Alternatives Considered:** (1) A single monolithic IPAM module with deeply
nested variable objects for pools. Rejected because the variable interface
becomes unmanageable (pools have their own sub-pools, each with CIDRs,
allocation rules, and tags). (2) Three modules (ipam, scope, pool). Rejected
because scopes are tightly coupled to the IPAM instance -- they have no
independent lifecycle and are always created at the same time as the IPAM.

---

## 2. Allocations Belong at Composition Level

**Decision:** `aws_vpc_ipam_pool_cidr_allocation` resources are not managed
by either the IPAM module or the pool module. They belong at the composition
or environment level.

**Rationale:** An allocation is the act of reserving an IP range from a pool
for a specific VPC. It connects two independently managed resources: a pool
(managed by the networking team) and a VPC (managed by the application team).
Neither module should own this cross-cutting concern.

In a composition like `eks-platform`, the allocation would look like:

```hcl
module "ipam"      { source = "../modules/aws-ipam" }
module "ipam_pool" { source = "../modules/aws-ipam-pool" }
module "vpc"       { source = "../modules/aws-vpc" }

resource "aws_vpc_ipam_pool_cidr_allocation" "this" {
  ipam_pool_id = module.ipam_pool.pool_id
  cidr         = module.vpc.vpc_cidr_block
}
```

Placing the allocation in either module would create a circular dependency:
the pool module would need to know about VPCs, or the VPC module would need
to know about IPAM pools.

---

## 3. Phased Approach to IPAM Adoption

**Decision:** IPAM adoption follows three phases:
- Phase 1 (this module): IPAM instance, scopes, Organizations delegation,
  resource discovery.
- Phase 2 (aws-ipam-pool): Pools, sub-pools, CIDR provisioning, RAM sharing.
- Phase 3 (VPC integration): Modify aws-vpc to optionally allocate CIDRs from
  IPAM pools instead of static CIDR blocks.

**Rationale:** Each phase is independently useful and testable. Phase 1 gives
visibility into existing IP usage (via resource discovery). Phase 2 enables
centralized IP management. Phase 3 completes the integration. Starting with
Phase 3 would require Phase 1 and 2 to exist first, so the ordering is
natural.

This also matches the learning progression: understanding IPAM concepts before
building pool hierarchies, and understanding pools before integrating them into
VPC provisioning.

---

## 4. Tier Defaults to "free"

**Decision:** `var.tier` defaults to `"free"`, overriding the AWS provider
default of `"advanced"`.

**Rationale:** The advanced tier incurs charges per active IP address managed
by IPAM. A module that defaults to "advanced" could surprise a user with costs
they did not expect -- especially in a learning or development context. The
principle is "default to the cheapest option and let consumers opt in to paid
features."

This does mean that features like resource discovery, Organizations
integration, and private GUA addresses require the user to explicitly set
`tier = "advanced"`. The tier-gating preconditions (Decision 6) ensure users
get a clear error if they try to enable an advanced feature on the free tier.

**Alternatives Considered:** Defaulting to "advanced" to match AWS behavior.
Rejected because the module's job is to provide safe defaults, not to mirror
provider defaults. The VPC module similarly overrides AWS defaults (e.g.,
`enable_dns_hostnames` defaults to `true` in the module but `false` in AWS).

**Cost Implication:** Prevents surprise billing. Users must consciously choose
the advanced tier.

---

## 5. Cascade Delete Defaults to False

**Decision:** `var.cascade_delete` defaults to `false`.

**Rationale:** When `cascade = true`, destroying the IPAM also destroys all
child scopes, pools, and allocations -- including allocations that may be in
use by production VPCs. This is a dangerous operation that should never be the
default.

With `cascade = false` (the default), Terraform will refuse to destroy an IPAM
that has active child resources. The operator must first remove pools and
allocations, then destroy the IPAM. This "speed bump" is intentional: it
forces deliberate cleanup.

The variable is named `cascade_delete` rather than the API argument name
`cascade`. The longer name is more descriptive -- `cascade` alone is ambiguous
(cascade what?), while `cascade_delete` clearly communicates the destructive
intent. This follows the coding convention of "descriptive nouns."

**Security Implication:** Prevents accidental destruction of IP address
management infrastructure.

---

## 6. Tier-Gating Preconditions

**Decision:** Three `lifecycle { precondition }` blocks prevent enabling
advanced-tier features on the free tier:
1. `aws_vpc_ipam.this`: `enable_private_gua` requires `tier = "advanced"`
2. `aws_vpc_ipam_organization_admin_account.this`: Organizations delegation
   requires `tier = "advanced"`
3. `aws_vpc_ipam_resource_discovery.this`: Resource discovery requires
   `tier = "advanced"`

**Rationale:** Without these preconditions, a user could set
`tier = "free"` and `resource_discovery_enabled = true`. The result would
either be a cryptic AWS API error at apply time or, worse, a resource that
appears to be created but does not function. Preconditions catch the mistake
at plan time with a clear, actionable error message.

**Why preconditions instead of variable validation blocks:** Terraform's
`validation` block on a variable can only reference that one variable. The
constraint "if feature X is enabled, then tier must be advanced" spans two
variables. `lifecycle { precondition }` is the correct mechanism for
cross-variable validation -- the same pattern established in the VPC module
for flow log destination constraints.

**Key Terraform behavior:** `precondition` blocks fire during `terraform plan`,
before any resources are created or modified. They produce errors that name
the specific constraint, unlike AWS API errors which are often opaque. This
is why preconditions are preferred over "let the API reject it."

**Alternatives Considered:** (1) Variable-level validation -- not supported
for cross-variable references. (2) `check` blocks -- these produce warnings,
not errors, so they would not prevent a bad apply. (3) Relying on AWS API
errors -- rejected because the errors are cryptic and fire at apply time.

---

## 7. Organizations Resources Included but Optional

**Decision:** The module includes `aws_vpc_ipam_organization_admin_account`
and `aws_vpc_ipam_resource_discovery` resources, but both default to disabled
(`delegated_admin_account_id = null`, `resource_discovery_enabled = false`).

**Rationale:** Organizations integration and resource discovery are core IPAM
capabilities, not separate concerns. They share the IPAM instance's lifecycle
(configured once during setup, rarely modified). Including them in the module
with safe defaults means:
1. Consumers who do not use Organizations get a clean, minimal IPAM.
2. Consumers who do use Organizations add two variables without needing a
   second module.
3. The module's interface naturally guides users to discover these features
   via variable descriptions.

**Alternatives Considered:** Separate modules for Organizations delegation and
resource discovery. Rejected because each would be a single-resource module
with no independent lifecycle -- the overhead of managing three modules for
what amounts to an IPAM setup wizard is not justified.

---

## 8. Resource Discovery Regions Fall Back to IPAM Regions

**Decision:** When `resource_discovery_operating_regions` is empty and
`resource_discovery_enabled` is true, the module uses `var.operating_regions`
as the discovery's operating regions.

**Rationale:** In the common case, the resource discovery monitors the same
regions as the IPAM. Forcing users to repeat the region list is unnecessary
friction and violates DRY. The fallback is implemented in `locals.tf`:

```hcl
resource_discovery_operating_regions = length(var.resource_discovery_operating_regions) > 0
  ? var.resource_discovery_operating_regions
  : var.operating_regions
```

The escape hatch (`resource_discovery_operating_regions`) exists for the
uncommon case where discovery should monitor a different set of regions than
the IPAM manages -- for example, monitoring a broad set of regions for
existing resources while only managing addresses in a subset.

---

## 9. Custom Scopes via map(string)

**Decision:** Custom scopes are defined as `map(string)` where keys are scope
names and values are descriptions, rather than `list(object({ name, description }))`.

**Rationale:** The map type has three advantages:
1. Keys become `for_each` instance keys naturally, meaning Terraform tracks
   scopes by name. Adding or removing a scope from the middle of a list would
   not shuffle the indexes of other scopes.
2. The interface is simpler: `{ production = "Production workloads" }` vs.
   `[{ name = "production", description = "Production workloads" }]`.
3. Map keys enforce uniqueness -- you cannot accidentally create two scopes
   with the same name.

The tradeoff is that the map value is limited to a single field (description).
If custom scopes needed additional configuration (e.g., per-scope tags), the
type would need to change to `map(object({ description, tags }))`. This is
acceptable because IPAM scopes have very few configurable attributes.

---

## 10. Delegated Admin as Nullable String

**Decision:** Organizations delegation is controlled by a single variable
`delegated_admin_account_id` (type `string`, default `null`). When non-null,
the resource is created. There is no separate boolean toggle.

**Rationale:** The alternative pattern -- `create_delegated_admin = true` plus
`delegated_admin_account_id = "123456789012"` -- creates a misconfiguration
risk. A user could set the boolean without the ID (error at apply time) or
set the ID without the boolean (resource silently not created, user confused).
By deriving the boolean from the ID:

```hcl
local.create_delegated_admin = var.delegated_admin_account_id != null
```

There is exactly one way to enable the feature, and it requires providing the
necessary data. This is the same pattern the VPC module uses with
`flow_log_destination_arn` -- a nullable variable that both enables a feature
and provides its configuration.

**Alternatives Considered:** Separate boolean + string. Rejected due to the
misconfiguration risk described above.

---

## 11. nullable = false on Key Variables

**Decision:** Five variables set `nullable = false`: `cascade_delete`,
`description`, `enable_private_gua`, `resource_discovery_enabled`, and `tier`.
The `name` and `operating_regions` variables (required, no default) also set
`nullable = false`.

**Rationale:** For variables with defaults, `nullable = false` prevents a
caller from passing `null` to bypass both the default value and validation
blocks. The most critical case is `tier`: without `nullable = false`, a caller
doing `tier = local.some_lookup_that_returns_null` would bypass the
`contains(["free", "advanced"], ...)` validation, send `null` to the provider,
and the provider would use its own default of `"advanced"` -- resulting in an
unexpected bill.

For variables without defaults (`name`, `operating_regions`), `nullable = false`
converts a confusing downstream error ("invalid value null for argument name")
into a clear variable-level error ("variable cannot be null").

**Key Terraform behavior:** When a variable is nullable (the default) and
receives `null`, Terraform skips all `validation` blocks. This means
validation alone is insufficient to protect against null input. The
combination of `nullable = false` plus validation provides complete input
protection.

---

## 12. Custom Scope Descriptions Must Be Non-Empty

**Decision:** The `custom_scopes` variable validates that every description
(map value) is non-empty after trimming whitespace.

**Rationale:** Custom IPAM scopes exist for organizational clarity -- they
separate IP address pools into logical boundaries (e.g., production vs.
development). A scope with an empty or whitespace-only description defeats
this purpose. When teams browse scopes in the AWS console, descriptions are
the primary way to understand what each scope is for.

The validation uses `trimspace()` to catch whitespace-only values like
`"   "`, which `length()` alone would accept.

```hcl
condition = alltrue([for k, v in var.custom_scopes : length(trimspace(v)) > 0])
```

**Alternatives Considered:** Allowing empty descriptions for flexibility.
Rejected because if you are creating a custom scope, you should be able to
explain why it exists. The default `{}` (no scopes) is the opt-out.

---

## 13. GovCloud Region Regex Fix

**Decision:** The region validation regex was changed from
`^[a-z]{2}(-[a-z]+-\d|gov-[a-z]+-\d)$` to
`^(us-gov-[a-z]+-\d|[a-z]{2}-[a-z]+-\d)$`.

**Rationale:** The original regex broke on `us-gov-west-1`. Here is why:
`[a-z]{2}` consumes `us`, then the alternation tries either `-[a-z]+-\d`
(standard regions) or `gov-[a-z]+-\d` (GovCloud). For GovCloud to match, the
remaining string after `us` would need to be `gov-west-1` -- but the actual
remaining string is `-gov-west-1` (note the leading hyphen). The regex
expected `usgov-west-1` with no hyphen between `us` and `gov`.

The fixed regex handles GovCloud as an explicit first alternative that matches
the full `us-gov-region-N` pattern. Standard regions remain the second
alternative. The fix was applied in both `operating_regions` and
`resource_discovery_operating_regions` validation blocks.

**Lesson learned:** Always test regexes against the exact strings they need to
match, especially for formats with irregular structure like GovCloud regions.
The original regex was written by pattern (two letters + suffix) but GovCloud
does not follow the standard region naming pattern -- it has an extra segment.

---

## 14. metered_account Variable Removed

**Decision:** The `metered_account` variable was declared by the module writer
but removed during review. A deferred comment in `variables.tf` explains the
version dependency.

**Rationale:** The `metered_account` argument on `aws_vpc_ipam` was added in
AWS provider v6.11.0 (August 2025). This module pins to `~> 5.0` in
`versions.tf`. When the reviewer attempted to wire the variable to the
resource and ran `terraform validate`, the provider rejected it:
`An argument named "metered_account" is not expected here.`

The original review flagged the variable as "declared but never used -- wire
it to the resource." This was based on the Terraform Registry documentation,
which reflects the `main` branch of the provider repository (v6.x). The
registry docs do not indicate which provider version introduced each argument.

**Lesson learned:** Always validate against the actual pinned provider version,
not the latest documentation. The Terraform Registry shows docs for the latest
release on `main`, which may include arguments unavailable in the version your
module pins to. Running `terraform init && terraform validate` catches these
mismatches before they become broken modules.

**Revisit when:** The module's provider constraint is upgraded to `~> 6.11` or
later. At that point, add the `metered_account` variable and wire it to
`aws_vpc_ipam.this`.

---

## 15. OU Exclusion on Resource Discovery

**Decision:** The `aws_vpc_ipam_resource_discovery` resource supports
`organizational_unit_exclusion` blocks to exclude specific OUs from IP
management. This is not exposed by the module. A comment in `main.tf`
documents the existence of this feature.

**Rationale:** OU exclusion is an edge case for organizations that want IPAM
to monitor most accounts but skip specific sandboxes, test accounts, or
third-party OUs. Exposing it in Phase 1 would add variable complexity
(a list of OU IDs with optional nesting) for a feature most users will not
need until they have a mature multi-account setup.

**Revisit when:** A user has a multi-account AWS Organization and needs to
exclude specific OUs from IPAM resource discovery.

---

## 16. External Resource Discovery Association

**Decision:** The module creates a resource discovery AND immediately
associates it with the IPAM. There is no way to associate an externally
created discovery.

**Rationale:** In a multi-account setup, a resource discovery might be created
in a member account and shared to the IPAM account via RAM. This module does
not support that pattern -- it always creates its own discovery. Supporting
external discoveries would require a new variable
(`external_resource_discovery_id`) and conditional logic to skip discovery
creation while still creating the association.

This was deferred because the module's current scope is single-account IPAM
management. The multi-account pattern requires additional infrastructure
(RAM sharing, cross-account trust) that would need its own module or
composition.

**Revisit when:** Building a multi-account IPAM composition where the
discovery is created in a different account than the IPAM.

---

## 17. Integration Tests Deferred

**Decision:** The module has 95 unit tests but no integration tests (tests
using `command = apply` against real AWS).

**Rationale:** Three factors make integration tests lower-value for this
module compared to the VPC module:

1. **Provisioning time:** IPAM instances are slow to create and destroy
   (minutes, not seconds), making integration test cycles expensive in both
   time and cost.
2. **Limited free-tier surface:** The free tier restricts testable features.
   Advanced-tier features would incur charges per active IP address during
   test runs.
3. **Unit tests cover all logic:** The 95 unit tests validate every variable
   default, every validation rejection, every precondition, every output
   value, and every conditional resource creation path. What remains
   untested is only "does the AWS API accept these arguments?" -- which is
   low-risk for a well-documented resource.

Integration tests are planned for Phase 2 (pool module) where the real value
of IPAM emerges: allocating CIDRs from pools and verifying VPCs receive the
correct address ranges. That interaction between pool and VPC is where API
surprises are most likely.

**Alternatives Considered:** A single integration test that creates and
destroys a minimal free-tier IPAM. Accepted as a future enhancement but
deferred because the unit test coverage is already comprehensive.

---

## 18. custom_scope_types Output Used Wrong Attribute

**Decision:** Changed `v.type` to `v.ipam_scope_type` in the
`custom_scope_types` output.

**Rationale:** The `aws_vpc_ipam_scope` resource exports `ipam_scope_type`
as its computed attribute for the scope classification (private or public),
not `type`. The `type` attribute does not exist on this resource. Using
`v.type` would cause an error at apply time when Terraform attempted to read
the attribute from the resource state.

This was caught by the test writer's `custom_scopes_unit_test.tftest.hcl`
before the module was ever applied to real infrastructure. The mock provider
does not surface this error because mock attributes are synthesized, but the
test assertions that check output values against expected scope types would
have revealed the mismatch.

**Lesson learned:** Always verify computed attribute names against the
provider documentation, not just intuition. Resource attributes in the AWS
provider do not always follow obvious naming patterns -- `ipam_scope_type`
includes the resource prefix while most other attributes (like `arn`, `id`)
do not.

---

## 19. GovCloud Region Regex Broke on us-gov-west-1

**Decision:** See [Decision 13](#13-govcloud-region-regex-fix) for the full
explanation. This entry documents how the bug was found.

**Rationale:** The test writer added a validation test case for
`us-gov-west-1` as a valid GovCloud region. The test expected the validation
to pass (valid input), but the regex rejected it. The test failure revealed
the regex bug before the module was used in a GovCloud environment.

This is an example of edge-case tests catching a real bug. Without a test
specifically targeting the GovCloud format, this would have gone unnoticed
until someone deployed to GovCloud -- likely months later, in a context where
debugging the regex failure would be time-consuming.

**Lesson learned:** When a validation regex claims to handle multiple formats
(standard regions, GovCloud regions), always write test cases for each format.
The "happy path" test (`us-east-1`) would have passed with the broken regex.
Only the GovCloud-specific test exposed the defect.
