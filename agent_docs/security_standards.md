# Security Standards

Reference for tf-reviewer when evaluating security posture.

## Encryption

- Encryption at rest enabled by default for all storage resources
- Use AWS-managed keys (SSE-S3, SSE-EBS) or customer-managed KMS keys
- Enable encryption in transit where applicable (TLS, HTTPS)

## Network Security

- No `0.0.0.0/0` in security group ingress unless explicitly justified
- Private subnets for workloads; public subnets only for load balancers/NAT
- Use security group references over CIDR blocks where possible
- Default deny: explicit allow rules only

## IAM

- Least privilege policies — no `*` actions or resources unless necessary
- Use IAM roles over IAM users for service authentication
- Separate roles per service/workload
- Condition keys where applicable (e.g., `aws:SourceArn`)

## Secrets Handling

- Mark outputs with `sensitive = true` for secrets, passwords, tokens
- No hardcoded credentials in `.tf` files
- No secrets in Terraform state — use AWS Secrets Manager or Parameter Store
- Use `sensitive` variables for values passed in

## Logging & Monitoring

- Enable CloudWatch Logs for applicable resources
- Enable VPC Flow Logs for network visibility
- Enable CloudTrail for API audit logging
- S3 access logging for buckets with sensitive data

## Security Scanning (Future)

Tools to integrate in Phase 5:
- **trivy** — vulnerability scanning for IaC
- **checkov** — static analysis for Terraform
- **tfsec** — security scanner for Terraform

## Review Checklist

When reviewing for security, check:

1. [ ] Encryption at rest enabled?
2. [ ] No overly permissive security groups?
3. [ ] IAM policies follow least privilege?
4. [ ] Sensitive values marked as sensitive?
5. [ ] No hardcoded credentials?
6. [ ] Private networking by default?
7. [ ] Logging enabled where applicable?
