# Design Decisions: AWS VPC Module

Captures the "why" behind every significant design choice made during the
review process. Each section records the decision, the rationale, alternatives
that were discussed, and any security implications.

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

## `nullable = false` on Required Variables

**Decision:** Both `name` and `cidr_block` set `nullable = false`.

**Rationale:** These variables have no default, making them required. But
Terraform allows passing `name = null` explicitly, which bypasses all
`validation` blocks (Terraform skips validation for null values). Without
`nullable = false`, a null `cidr_block` would pass validation and then crash
deep in the AWS provider with a confusing error. With `nullable = false`,
Terraform rejects the null at variable evaluation with a clear message.

**Alternatives Considered:** Relying on downstream errors to catch nulls.
Rejected because the error messages from the AWS provider are cryptic and do
not point back to the variable as the root cause.

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

## Tag Merging Strategy

**Decision:** `local.tags` merges `{ Name = var.name }` with `var.tags`, with
user tags taking precedence. Sub-resources (IGW, SG, flow log) merge additional
Name tags on top of `local.tags`.

**Rationale:** The `merge()` function gives precedence to later maps. If a
user passes `tags = { Name = "custom" }`, their value overwrites the module's
default. This lets the module set sensible defaults while allowing full caller
control. Each sub-resource gets its own descriptive Name (e.g.,
`"my-vpc-igw"`) while sharing common tags like Environment or Team.

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

---

## Boolean Toggles Use `count`, Not `for_each`

**Decision:** Resources like IGW, default SG, and flow log use
`count = var.create_x ? 1 : 0`.

**Rationale:** Per `module_design.md`, `count` is appropriate for boolean
create/don't-create toggles on singleton resources. `for_each` would require
manufacturing a map or set from a boolean, adding complexity for no benefit.
`for_each` is reserved for resources that may have multiple named instances.

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
