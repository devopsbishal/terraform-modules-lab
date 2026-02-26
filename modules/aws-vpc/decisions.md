# Design Decisions: AWS VPC Module

Captures the "why" behind every significant design choice made during the
review process. Each section records the decision, the rationale, alternatives
that were discussed, and any security implications.

This document serves as the learning artifact for the module -- someone reading
it should understand not just WHAT the module does, but WHY every choice was
made, and what tradeoffs were weighed.

---

## Table of Contents

**Architecture & Scope**
1. [Module Scope: Bundling Flow Logs, IAM, and CloudWatch](#module-scope-bundling-flow-logs-iam-and-cloudwatch)
2. [Module Boundary Heuristic](#module-boundary-heuristic)

**Security Decisions**
3. [Default Security Group Locked Down](#default-security-group-locked-down)
4. [Flow Logs Enabled by Default](#flow-logs-enabled-by-default)
5. [IAM Policy: Least Privilege](#iam-policy-least-privilege)
6. [Confused Deputy Protection on Trust Policy](#confused-deputy-protection-on-trust-policy)
7. [Optional KMS Encryption for CloudWatch Log Group](#optional-kms-encryption-for-cloudwatch-log-group)
8. [Inline IAM Policy vs. Managed Policy](#inline-iam-policy-vs-managed-policy)

**Variable Design**
9. [`cidr_block` Required With No Default](#cidr_block-required-with-no-default)
10. [CIDR Prefix Range: /16 to /24](#cidr-prefix-range-16-to-24)
11. [CIDR Validation: `can()` Guard on Prefix Length Check](#cidr-validation-can-guard-on-prefix-length-check)
12. [Name Length: 46 Characters Maximum](#name-length-46-characters-maximum)
13. [`nullable = false` on Required Variables](#nullable--false-on-required-variables)
14. [DNS Hostnames Default to True](#dns-hostnames-default-to-true)
15. [CloudWatch as Default Flow Log Destination](#cloudwatch-as-default-flow-log-destination)
16. [Flow Log Aggregation: 600 Seconds Default](#flow-log-aggregation-600-seconds-default)
17. [Cross-Variable Preconditions](#cross-variable-preconditions)
18. [External CloudWatch Log Group Support](#external-cloudwatch-log-group-support)

**Naming & Conventions**
19. [Naming Conventions](#naming-conventions)
20. [CloudWatch Log Group Naming: VPC ID Over Module Name](#cloudwatch-log-group-naming-vpc-id-over-module-name)
21. [Tag Merging Strategy](#tag-merging-strategy)
22. [Boolean Toggles Use `count`, Not `for_each`](#boolean-toggles-use-count-not-for_each)
23. [Data Sources Co-located in `main.tf`](#data-sources-co-located-in-maintf)
24. [Conditional Logic Centralized in Locals](#conditional-logic-centralized-in-locals)

**Testing Strategy**
25. [Test Organization: Four Unit Files Plus Integration](#test-organization-four-unit-files-plus-integration)
26. [Mock Provider with `override_data` Blocks](#mock-provider-with-override_data-blocks)
27. [Integration Test: Sequential Apply for Lifecycle Coverage](#integration-test-sequential-apply-for-lifecycle-coverage)
28. [Deferred Integration Test Scenarios](#deferred-integration-test-scenarios)

**Deferred Decisions**
29. [Deferred Decisions](#deferred-decisions)

**Review Findings**
30. [Review Findings: Potential Improvements](#review-findings-potential-improvements)

---

## Module Scope: Bundling Flow Logs, IAM, and CloudWatch

**Decision:** Keep VPC flow logs, the supporting IAM role, and the CloudWatch
log group inside the VPC module rather than extracting them into separate
modules.

**Rationale:** The user challenged this scope with two questions during review.

*"Why not have a dedicated IAM role module and pass the ARN in?"* --
The flow log IAM role is a subordinate implementation detail, not a standalone
concern. It exists only to allow the VPC flow log service to write to one
specific CloudWatch log group. It has no independent lifecycle (you would never
modify the role without also modifying the flow log), it is not reusable
(the policy is scoped to a single log group ARN), and extracting it creates a
circular dependency: the IAM policy needs the log group ARN, but the log group
might be in a separate module that needs the IAM role ARN. What was three
resources inside one module becomes three modules with fragile cross-wiring,
and every consumer pays that complexity.

*"Can't VPC Flow Logs be a separate module entirely?"* --
This is a closer call. Flow logs have their own configuration surface
(destination type, aggregation interval, traffic type), could target subnets
or ENIs (not just VPCs), and might change independently of the VPC. However,
bundling wins for this project because:

1. Secure by default -- if flow logs are a separate module, consumers who
   forget to add them get a VPC with no audit logging. Bundling means every
   VPC has flow logs from day one.
2. Simple consumer experience -- one module call produces a fully observable
   VPC. No wiring required.
3. Phase 1 learning project -- premature decomposition creates composition
   complexity without delivering value yet.

The `flow_log_enabled = false` escape hatch lets users who need custom flow log
setups disable the built-in one. The `flow_log_destination_arn` +
`flow_log_iam_role_arn` variables let users bring their own log group and role.

**Alternatives Considered:** (1) Dedicated `aws-iam-role` module for the flow
log role -- rejected due to circular dependency. (2) Dedicated
`aws-vpc-flow-log` module -- deferred, not rejected. Revisit if the project
needs per-subnet flow logs, a central logging team manages destinations
independently, or flow log configuration churn exceeds VPC configuration churn.

**Security Implication:** Bundling enforces a "secure by default" posture.
Splitting would turn security into an opt-in that consumers must remember.

---

## Module Boundary Heuristic

**Decision:** Established a four-criteria test for bundling vs. splitting,
derived from the discussion above and `module_design.md`.

**Bundle when:** the subordinate resource (1) exists only to serve the parent,
(2) has no independent lifecycle, (3) would never be consumed standalone, and
(4) bundling creates a "pit of success" for the consumer.

**Split when:** the subordinate resource (1) has its own configuration
complexity, (2) changes independently, (3) could serve multiple parents, or
(4) bundling forces consumers into a one-size-fits-all pattern.

When the criteria are mixed (as with flow logs), default to the option that
makes the consumer's life easier and the security posture stronger.

---

## Default Security Group Locked Down

**Decision:** `manage_default_security_group` defaults to `true`, and the
`aws_default_security_group` resource has no ingress or egress blocks.

**Rationale:** AWS creates every VPC with a default security group that allows
all outbound traffic and all inbound traffic from resources in the same group.
If someone launches a resource without specifying a security group, it inherits
this default. By adopting the default SG with no rules, the module strips all
permissions. This is a defense-in-depth measure: the mistake of forgetting to
assign a security group no longer results in network exposure.

The `aws_default_security_group` resource is special in Terraform: it does not
create a new security group but "adopts" the existing default SG created by
AWS. By defining it with no `ingress` or `egress` blocks, Terraform removes
any rules that were there. This is the only way to lock down the default SG
because you cannot delete it -- it always exists in every VPC.

**Security Implication:** Implements "default deny" as required by
`security_standards.md`. Workloads must use purpose-built security groups.

---

## Flow Logs Enabled by Default

**Decision:** `flow_log_enabled` defaults to `true`.

**Rationale:** Secure-by-default philosophy. VPC flow logs provide network
traffic visibility and are a baseline security control per
`security_standards.md`. Making them opt-out rather than opt-in means every VPC
has audit logging from creation. The cost of forgetting flow logs (no network
visibility during an incident) far exceeds the cost of having them
(CloudWatch storage charges).

---

## IAM Policy: Least Privilege

**Decision:** The flow log IAM role grants only `logs:CreateLogStream` and
`logs:PutLogEvents`. The original policy also included `logs:CreateLogGroup`,
`logs:DescribeLogGroups`, and `logs:DescribeLogStreams`.

**Rationale:** Terraform creates the CloudWatch log group via
`aws_cloudwatch_log_group.flow_log`, so the flow log service never needs
`CreateLogGroup`. The `Describe*` actions are read-only but unnecessary for
the write-only purpose of this role. If the role were compromised (confused
deputy, misconfigured trust), `DescribeLogGroups` would let an attacker
enumerate all log group names across the account -- useful reconnaissance for
lateral movement.

The IAM policy resource is scoped to `"${aws_cloudwatch_log_group.flow_log[0].arn}:*"`
(the `:*` is required because CloudWatch Logs API actions operate on log
streams, which are children of the log group ARN).

**Alternatives Considered:** Keeping the broader set for "operational
flexibility." Rejected because the role has a single, narrow purpose and
broader permissions expand the blast radius of a compromise.

**Security Implication:** Reduces attack surface. The role can only write to
one specific log group.

---

## Confused Deputy Protection on Trust Policy

**Decision:** The flow log IAM role's trust policy includes `aws:SourceAccount`
and `aws:SourceArn` condition keys, restricting which principals can assume it.

**Rationale:** Without conditions, any `vpc-flow-logs.amazonaws.com` service
call from any account could assume this role (the confused deputy problem). In
a multi-account organization, a foreign account's flow log could potentially
write data into your CloudWatch log group, polluting audit trails or consuming
storage quota. The `aws:SourceAccount` condition restricts to the same AWS
account. The `aws:SourceArn` condition restricts to VPC flow log resources
specifically.

The `aws:SourceArn` uses `ArnLike` with a wildcard pattern
(`arn:aws:ec2:*:ACCOUNT_ID:vpc-flow-log/*`) rather than an exact ARN because
the flow log ARN is not known until after the flow log is created, and the
trust policy must exist before the flow log can reference the role.

**Alternatives Considered:** Omitting conditions for simplicity. Rejected
because the confused deputy is a well-documented AWS attack vector and the fix
is a few lines of HCL.

**Security Implication:** Prevents cross-account role assumption. Requires a
`data.aws_caller_identity.current` data source, which adds a minor dependency
but is standard practice.

---

## Optional KMS Encryption for CloudWatch Log Group

**Decision:** Added `flow_log_cloudwatch_kms_key_id` variable (default `null`)
that wires through to `kms_key_id` on the CloudWatch log group.

**Rationale:** VPC flow logs contain network metadata (source/destination IPs,
ports, protocols, packet counts) that reveals internal architecture and
communication patterns. CloudWatch's default encryption uses AWS-managed keys,
which is acceptable for most use cases. Customer-managed KMS keys are required
for stricter compliance frameworks (HIPAA, PCI-DSS, FedRAMP) and give control
over who can decrypt logs and the ability to revoke access.

**Alternatives Considered:** Always requiring a KMS key. Rejected because it
would force every consumer to provision a KMS key even in non-compliance
environments, adding cost and complexity for no benefit.

**Security Implication:** Encryption at rest is always on (CloudWatch default).
This option upgrades to customer-managed keys when needed.

---

## Inline IAM Policy vs. Managed Policy

**Decision:** The flow log IAM role uses `aws_iam_role_policy` (an inline
policy) rather than `aws_iam_policy` + `aws_iam_role_policy_attachment`
(a managed policy).

**Rationale:** An inline policy is embedded directly in the role and has a 1:1
lifecycle with it. When the role is destroyed (e.g., flow logs disabled), the
inline policy is automatically deleted. A managed policy would be a separate
resource that could be orphaned if the role were destroyed outside of Terraform
or if the destroy order were unexpected. Since this policy has no reuse case
(it is scoped to a single log group ARN), the simplicity of inline wins.

**Alternatives Considered:** `aws_iam_policy` + `aws_iam_role_policy_attachment`.
This pattern is better when a policy needs to be shared across multiple roles
or when the policy must survive the role's deletion. Neither applies here.

---

## `cidr_block` Required With No Default

**Decision:** `cidr_block` is a required variable with no default value.

**Rationale:** There is no safe universal CIDR default. If the module defaulted
to `10.0.0.0/16`, two VPCs in the same account would collide when peered. VPC
peering, Transit Gateway, and VPN connections all require non-overlapping
address spaces. Forcing the caller to choose prevents silent address conflicts.

---

## CIDR Prefix Range: /16 to /24

**Decision:** The `cidr_block` validation restricts prefix length to /16
through /24.

**Rationale:** A /16 (65,536 IPs) is the maximum for a single VPC CIDR in AWS.
A /24 (256 IPs) is the practical minimum -- AWS reserves 5 IPs per subnet, so
anything smaller cannot meaningfully subnet further. This is an opinionated
guardrail that prevents two categories of mistakes: accidentally requesting
more address space than AWS allows, and creating a VPC too small to be useful.

Note: AWS technically allows CIDRs from /16 to /28. The /24 lower bound is an
opinionated choice -- a /28 VPC (16 IPs, 11 usable after AWS reservations) is
technically valid but cannot host even a single meaningful subnet. If a
legitimate use case for /25-/28 arises, the validation can be relaxed.

---

## CIDR Validation: `can()` Guard on Prefix Length Check

**Decision:** The second `cidr_block` validation wraps the prefix length
extraction in `can()`:
`can(tonumber(split("/", var.cidr_block)[1])) && tonumber(...) >= 16 && ...`

**Rationale:** Found during test writing. The first validation
(`can(cidrhost(...))`) catches most malformed CIDRs, but Terraform evaluates
all validation blocks -- it does not short-circuit on the first failure. So
inputs like `"not-a-cidr"` or `"10.0.0.0"` (no slash) would cause `split("/")`
to produce an array without index `[1]`, and `tonumber()` would crash with an
evaluation error rather than a clean validation failure. The `can()` wrapper
catches the error and returns `false`, allowing the `error_message` to fire.

**Key Terraform behavior:** Validation blocks within a single variable are ALL
evaluated, regardless of whether earlier ones fail. This is different from most
programming languages where validators short-circuit. Each validation block
must be independently safe against any input, including inputs that would fail
earlier validations.

**Alternatives Considered:** Combining both validations into a single block.
Rejected because separate blocks produce separate, specific error messages.
A user passing `"hello/8"` needs to see two distinct messages: "not valid CIDR"
and "prefix out of range."

---

## Name Length: 46 Characters Maximum

**Decision:** The `name` variable allows 1 to 46 characters, not the original
64.

**Rationale:** Found during test writing. The module appends
`-vpc-flow-log-role` (18 characters) to `var.name` to create the IAM role
name. AWS IAM role names have a hard 64-character limit. A 47-character name
would produce a 65-character role name, failing at the AWS API with a cryptic
error. The validation now catches this at plan time: `46 + 18 = 64`.

**Alternatives Considered:** Shortening the IAM role suffix instead (e.g.,
`-fl-role` instead of `-vpc-flow-log-role`). Rejected because descriptive
resource names are more valuable than supporting very long VPC names, and 46
characters is generous for a VPC name.

**Lesson learned:** When a module derives resource names from an input
variable, the validation on that variable must account for the longest suffix.
Always check derived names against AWS service limits.

---

## `nullable = false` on Required Variables

**Decision:** Both `name` and `cidr_block` set `nullable = false`.

**Rationale:** These variables have no default, making them required. But
Terraform allows passing `name = null` explicitly, which bypasses all
`validation` blocks (Terraform skips validation for null values). Without
`nullable = false`, a null `cidr_block` would pass validation and then crash
deep in the AWS provider with a confusing error. With `nullable = false`,
Terraform rejects the null at variable evaluation with a clear message.

**Key Terraform behavior:** `nullable` and `validation` are independent.
Terraform evaluates `nullable` first. If a variable is nullable (the default)
and receives `null`, validation blocks are skipped entirely. This means
validation alone is not sufficient to protect required variables from null
input. The combination of `nullable = false` plus validation blocks provides
complete input protection.

**Alternatives Considered:** Relying on downstream errors to catch nulls.
Rejected because the error messages from the AWS provider are cryptic and do
not point back to the variable as the root cause.

---

## DNS Hostnames Default to True

**Decision:** `enable_dns_hostnames` defaults to `true`, overriding the AWS
default of `false`.

**Rationale:** DNS hostnames are required for: (1) EKS clusters, (2) Route 53
private hosted zones, (3) VPC endpoints with private DNS, and (4) EC2
instances to receive public DNS names. Since this project targets EKS and most
modern AWS architectures need DNS hostnames, defaulting to `true` avoids a
common "why doesn't my service work?" debugging session. Users who need the AWS
default can explicitly set `false`.

**Note:** `enable_dns_support` defaults to `true` (matching the AWS default).
DNS hostnames require DNS support to be enabled. If a user sets
`enable_dns_hostnames = true` and `enable_dns_support = false`, DNS hostnames
silently will not work. The variable description warns about this dependency.
A precondition enforcing the constraint is a potential future improvement (see
Review Findings).

---

## CloudWatch as Default Flow Log Destination

**Decision:** `flow_log_destination_type` defaults to `"cloud-watch-logs"`.

**Rationale:** CloudWatch requires no pre-existing infrastructure. The module
auto-creates the log group and IAM role. An S3 destination would require the
user to have already provisioned a bucket, adding a dependency that makes the
"just works" experience impossible. Users with centralized logging pipelines
can switch to S3 by providing a bucket ARN.

---

## Flow Log Aggregation: 600 Seconds Default

**Decision:** `flow_log_max_aggregation_interval` defaults to `600` (10
minutes).

**Rationale:** The 60-second option provides near-real-time visibility but
generates roughly 10x the log volume, increasing CloudWatch costs
proportionally. The 600-second default balances cost and visibility for most
use cases. Security-sensitive workloads that need faster anomaly detection can
override to 60.

---

## Cross-Variable Preconditions

**Decision:** The `aws_flow_log` resource has two `lifecycle { precondition }`
blocks: one requiring `flow_log_destination_arn` when `destination_type` is
`"s3"`, and one requiring `flow_log_iam_role_arn` when a user provides an
external CloudWatch log group ARN.

**Rationale:** Terraform `validation` blocks on variables cannot reference
other variables. Cross-variable constraints must use `precondition` on a
resource or a `check` block. Preconditions were chosen because they fire at
plan time (before any resources are created) and produce actionable error
messages that name the specific variables involved.

**Alternatives Considered:** (1) `validation` blocks with cross-variable
references -- not supported by Terraform. (2) `check` blocks -- these produce
warnings, not errors, so they would not prevent a bad apply. (3) Relying on
AWS API errors -- rejected because the errors are cryptic and fire at apply
time rather than plan time.

---

## External CloudWatch Log Group Support

**Decision:** When `flow_log_destination_type` is `"cloud-watch-logs"` and
`flow_log_destination_arn` is provided, the module skips creating its own log
group and IAM role. The user must also provide `flow_log_iam_role_arn`.

**Rationale:** Found during test writing. The original module always created
its own log group even when an external ARN was provided, ignoring the user's
input. The fix required updating `create_flow_log_log_group` in locals to also
check `var.flow_log_destination_arn == null`, and adding a new
`flow_log_iam_role_arn` variable. The IAM role cannot be auto-created in this
case because its policy is scoped to the auto-created log group's ARN, which
does not exist when the user brings their own.

A precondition ensures users who provide an external log group also provide an
external role, catching the mistake at plan time.

**Alternatives Considered:** (1) Auto-creating the IAM role scoped to the
user-provided log group ARN. Rejected because it assumes the module has
permission to create IAM roles in environments where a security team might
manage all IAM. (2) Always creating the log group and ignoring the user's ARN.
Rejected because it wastes resources and confuses users who expect their input
to have an effect.

---

## Naming Conventions

**Decision:** Singleton resources use `this` (e.g., `aws_vpc.this`). The input
variable is `cidr_block` (not `vpc_cidr_block`), while the output is
`vpc_cidr_block`.

**Rationale:** Per `coding_conventions.md`, `this` is for singleton resources.
Inside the VPC module, the context is already "VPC" so prefixing inputs with
`vpc_` is redundant. Outputs are consumed from outside the module where context
matters, so `vpc_cidr_block` prevents ambiguity when a composition has both VPC
and subnet CIDR outputs.

Supporting resources that are not singletons use descriptive names:
`aws_iam_role.flow_log`, `aws_cloudwatch_log_group.flow_log`. This makes it
clear what each resource serves when reading `main.tf`.

---

## CloudWatch Log Group Naming: VPC ID Over Module Name

**Decision:** The CloudWatch log group is named `/aws/vpc-flow-log/${vpc_id}`
using the VPC's AWS-assigned ID rather than `var.name`.

**Rationale:** The VPC ID is globally unique within a region. Using `var.name`
could cause collisions if two VPCs in the same account share a name (Terraform
would error when both try to create `/aws/vpc-flow-log/my-vpc`). The VPC ID
also follows the AWS convention where service log groups reference the resource
ID (e.g., `/aws/lambda/<function-name>`), making it easy to find the log group
for a specific VPC in the CloudWatch console.

The `/aws/` prefix namespace is an AWS convention for service-generated logs.
While not strictly reserved, using it signals that the log group contains
AWS service output rather than application logs.

---

## Tag Merging Strategy

**Decision:** `local.tags` merges `{ Name = var.name }` with `var.tags`, with
user tags taking precedence. Sub-resources (IGW, SG, flow log) merge additional
Name tags on top of `local.tags`.

**Rationale:** The `merge()` function gives precedence to later maps. If a
user passes `tags = { Name = "custom" }`, their value overwrites the module's
default. This lets the module set sensible defaults while allowing full caller
control. Each sub-resource gets its own descriptive Name (e.g.,
`"my-vpc-igw"`) while sharing common tags like Environment or Team.

The layering works as follows:
1. `local.tags` = `{ Name = "my-vpc" }` + user's `var.tags` (user wins)
2. IGW tags = `local.tags` + `{ Name = "my-vpc-igw" }` (sub-resource Name wins)

This means a user's `tags = { Name = "override" }` would set the VPC Name tag
to "override" but the IGW Name tag would still be "my-vpc-igw" because step 2
overwrites it. This is intentional: sub-resource names should be descriptive
and unique.

---

## Boolean Toggles Use `count`, Not `for_each`

**Decision:** Resources like IGW, default SG, and flow log use
`count = var.create_x ? 1 : 0`.

**Rationale:** Per `module_design.md`, `count` is appropriate for boolean
create/don't-create toggles on singleton resources. `for_each` would require
manufacturing a map or set from a boolean, adding complexity for no benefit.
`for_each` is reserved for resources that may have multiple named instances.

The downside of `count` is that conditional resources must be accessed with
`[0]` indexing (e.g., `aws_internet_gateway.this[0].id`), and outputs must
use ternary expressions to handle the empty list case. This is a well-known
Terraform ergonomics tradeoff that the community has accepted for boolean
toggles.

---

## Data Sources Co-located in `main.tf`

**Decision:** The `data.aws_caller_identity.current`,
`data.aws_iam_policy_document.flow_log_assume_role`, and
`data.aws_iam_policy_document.flow_log_permissions` data sources are in
`main.tf` rather than a separate `data.tf`.

**Rationale:** `coding_conventions.md` lists `data.tf` as optional. With only
three data sources, all closely tied to the IAM resources directly below them
in `main.tf`, co-location keeps related code together. If the module grew to
include many data sources for different purposes, a `data.tf` separation would
improve navigability.

---

## Conditional Logic Centralized in Locals

**Decision:** Three local booleans govern conditional resource creation:
- `create_flow_log` = `var.flow_log_enabled`
- `create_flow_log_log_group` = flow log enabled AND destination is
  cloud-watch-logs AND no external destination ARN provided
- `create_flow_log_iam_role` = same as `create_flow_log_log_group`

**Rationale:** Centralizing conditional logic in locals avoids duplicating
multi-clause boolean expressions across `count` attributes on 5+ resources.
Each resource's `count` references a single, named boolean, making the code
self-documenting. The local names describe the intent ("should I create this?")
rather than the mechanism ("is this flag true and that flag null?").

The chain `create_flow_log_iam_role = create_flow_log_log_group` encodes the
design rule that the IAM role exists if and only if the module creates its own
log group. This coupling is intentional: the IAM policy's `resources` field
references the auto-created log group ARN, so the role is useless without it.

---

## Test Organization: Four Unit Files Plus Integration

**Decision:** Unit tests are split across four files by purpose:
- `defaults_unit_test.tftest.hcl` (24 tests) -- verifies every default value
- `validation_unit_test.tftest.hcl` (31 tests) -- verifies every validation
  rejects bad input
- `custom_unit_test.tftest.hcl` (27 tests) -- verifies non-default values,
  feature toggles, destination types, external log group support
- `edge_cases_unit_test.tftest.hcl` (20 tests) -- boundary values, name
  propagation, tag propagation across all resources

Integration tests are in a single file:
- `full_integration_test.tftest.hcl` (4 apply scenarios)

**Rationale:** Splitting by purpose makes it easy to run a specific category
(`terraform test -filter=tests/validation_unit_test.tftest.hcl`) and keeps
file sizes manageable. The four-way split mirrors a natural test design
hierarchy: "does it work by default?", "does it reject bad input?", "does it
accept good custom input?", "does it handle edge cases?".

All unit tests use `command = plan` with `mock_provider "aws"`, which means
they run without AWS credentials, complete in seconds, and test the module's
logic rather than AWS API behavior.

**Alternatives Considered:** A single monolithic test file. Rejected because
102 tests in one file is hard to navigate. Also considered one file per
resource -- rejected because many tests (e.g., "minimal VPC") assert across
multiple resources simultaneously.

---

## Mock Provider with `override_data` Blocks

**Decision:** Every unit test file declares the same `mock_provider "aws"` with
three `override_data` blocks for `data.aws_caller_identity.current[0]`,
`data.aws_iam_policy_document.flow_log_assume_role[0]`, and
`data.aws_iam_policy_document.flow_log_permissions[0]`.

**Rationale:** The basic `mock_provider "aws" {}` returns empty/null values for
data sources. The `data.aws_iam_policy_document` sources generate JSON policy
documents that the `aws_iam_role` resource validates at plan time. A null or
empty `assume_role_policy` causes a plan-time error: "contains an invalid JSON
policy." The `override_data` blocks provide realistic mock values that satisfy
the downstream resources.

The `[0]` index is required because these data sources use `count`. Terraform's
mock override targets must match the specific instance address.

**Key learning:** When a module uses `data` sources that generate computed
values consumed by other resources, the mock provider needs `override_data`
blocks -- not just an empty mock. This is a common gotcha when adding tests to
an existing module.

---

## Integration Test: Sequential Apply for Lifecycle Coverage

**Decision:** The integration test file contains 4 sequential `run` blocks
using `command = apply`, each creating a different VPC configuration.

**Rationale:** Terraform test `run` blocks in the same file share state.
Sequential runs replace the previous configuration, which means Terraform
destroys resources from the previous run before creating the new ones. This
provides implicit lifecycle testing:

1. Run 1: Full-featured VPC (creates everything)
2. Run 2: Minimal VPC (destroys IGW, flow log, IAM role, CloudWatch log group)
3. Run 3: Flow log with 60s aggregation (recreates flow log resources)
4. Run 4: IPv6 VPC (exercises IPv6 attribute path)

The transition from run 1 to run 2 exercises the destroy path for every
conditional resource. This catches issues where Terraform cannot cleanly
destroy resources due to missing dependency ordering or lifecycle constraints.

**Alternatives Considered:** Separate integration test files for each scenario.
Rejected because each file would need its own full create/destroy cycle,
roughly tripling the wall-clock time and AWS API calls.

---

## Deferred Integration Test Scenarios

**Decision:** Three integration test scenarios were explicitly deferred:

1. **S3 flow log destination** -- Would require creating an S3 bucket with the
   correct bucket policy before the VPC module runs. This cross-module
   dependency adds complexity to the test setup.

2. **External CloudWatch log group** -- Would require creating a log group and
   IAM role outside the module, then passing their ARNs in. Similar cross-
   module test setup complexity.

3. **KMS-encrypted CloudWatch log group** -- Would require creating a KMS key
   with the correct key policy allowing CloudWatch Logs to use it. KMS keys
   cost $1/month and cannot be immediately deleted (minimum 7-day waiting
   period).

**Rationale:** Unit tests (using mock providers) already validate the module's
logic for all three scenarios: correct resource creation, correct resource
skipping, correct output values. Integration tests would verify that the AWS
API accepts the configuration, but the risk of API-level surprises is low for
these well-documented patterns. The cost (test complexity, AWS charges, test
runtime) does not justify the marginal confidence gain at this stage.

**Revisit when:** Building compositions that wire these patterns, or if a
deployment fails in a way that unit tests did not catch.

---

## Deferred Decisions

**Flow log module extraction:** If the project later needs per-subnet or
per-ENI flow logs, multiple flow logs per VPC, or a central logging team
managing destinations independently, the flow log resources should be extracted
into a standalone `aws-vpc-flow-log` module. The VPC module would then default
`flow_log_enabled = false` and consumers would wire the separate module.

**`create_vpc` toggle:** Many community modules include a `create` variable
that gates the entire module, useful in compositions where you pass in an
existing VPC ID. Deferred because it adds conditional complexity across all 7+
resources without delivering value in Phase 1. Revisit when building
compositions that need to reference existing VPCs.

**IPv6-only or dual-stack mode:** The module supports requesting an IPv6 CIDR
block but does not configure IPv6-specific resources (e.g., egress-only
internet gateway for IPv6). This is sufficient for Phase 1. Revisit when the
project needs IPv6 egress or dual-stack subnets.

---

## Review Findings: Potential Improvements

These findings were identified during the comprehensive review. They are
documented here for future reference rather than requiring immediate action.

### DNS Support Precondition (Medium Priority)

When `enable_dns_hostnames = true` and `enable_dns_support = false`, DNS
hostnames silently do not work. AWS requires DNS support as a prerequisite.
Adding a precondition on the VPC resource would catch this at plan time:

```hcl
lifecycle {
  precondition {
    condition     = var.enable_dns_hostnames == false || var.enable_dns_support == true
    error_message = "enable_dns_support must be true when enable_dns_hostnames is true."
  }
}
```

The variable description mentions this dependency, but a precondition would
enforce it. Deferred because it is a valid-but-useless configuration rather
than a breaking one.

### `nullable = false` on Boolean Variables (Low Priority)

The `name` and `cidr_block` variables use `nullable = false`, but the boolean
variables (`create_igw`, `flow_log_enabled`, `manage_default_security_group`,
etc.) do not. A caller passing `create_igw = null` would get a type error from
the `count` expression rather than a clean "variable cannot be null" message.
Adding `nullable = false` to all variables with defaults would make the module
more defensive. Deferred because explicitly passing `null` for a boolean is
uncommon.

### Stale Test Comment (Trivial)

In `validation_unit_test.tftest.hcl` line 118, the section header reads
"Length Validation (1 to 64 characters)" but the actual validation enforces
1 to 46 characters. The test inputs are correct -- only the comment is stale
from before the name length decision was made.
