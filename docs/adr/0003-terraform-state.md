# 3. Terraform state in S3 with S3-native locking

Status: accepted

## Context
State needs to be shared between a laptop and CI, protected from corruption by concurrent
runs, and recoverable after a bad apply.

## Decision
- One S3 bucket per account, created by the `bootstrap` stack, with versioning, encryption,
  public access blocked and TLS-only access.
- Locking uses Terraform's S3-native lock file (`use_lockfile = true`, Terraform >= 1.10)
  instead of a DynamoDB table, which is now the recommended approach.
- The bootstrap stack keeps local state, because it creates the bucket everything else uses.
  It changes rarely and is applied by a human with admin rights.

## Consequences
- One fewer resource to run and pay for.
- The plan role needs `s3:PutObject`/`DeleteObject` on the state bucket, because writing the
  lock file is a write even during `plan`.
- Previous state versions can be restored from S3 versioning if an apply goes wrong.
