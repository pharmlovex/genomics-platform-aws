# 2. No NAT gateway by default

Status: accepted (for dev)

## Context
Compute instances need outbound access to pull container images and to call AWS APIs.
The textbook design puts them in private subnets behind a NAT gateway. A NAT gateway costs
about $35 a month per AZ just to exist, plus a per-GB processing charge. That would make it
most of this platform's bill.

## Decision
In dev, compute runs in public subnets with public IPs. The security group allows **no
inbound traffic at all**, instances use IMDSv2, and access is through SSM Session Manager
rather than SSH. S3 traffic goes through a free S3 gateway endpoint, so genomic data never
crosses the public internet or a NAT.

The `enable_nat` variable moves compute into private subnets behind a NAT gateway with a
one-line change.

## Consequences
- Idle network cost is effectively zero.
- Instances are addressable from the internet but unreachable, because nothing inbound is
  allowed. That is acceptable for public test data. **For real patient data, set
  `enable_nat = true`** (or use interface endpoints for ECR, Logs and ECS) and keep compute private.
- Checkov flags public IPs (`CKV_AWS_130`). The skip in `.checkov.yml` points to this ADR.
