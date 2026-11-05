# Runbook

## Deploy a change

1. Branch, change `infra/`, open a PR.
2. Read the plan comment. Look out for any `destroy` or `replace` of a bucket or the KMS key.
3. Merge. Approve the `dev` environment when GitHub asks.

## A Batch job failed

You will get an email: "Batch job ... failed. Reason: ...".

1. Find the task in the Nextflow output; the run's `trace.tsv` lists every task and its exit code.
2. Read the job log: CloudWatch Logs -&gt; `/aws/batch/job` -&gt; stream named after the job ID.
3. Common causes:
 | Symptom | Likely cause | Fix |
 |---|---|---|
 | `Host EC2 (instance ...) terminated` | Spot interruption | Usually retried automatically; if not, rerun with `-resume` |
 | `exit 137` / OutOfMemory | Task memory too low | Raise `memory` for that process |
 | `aws: command not found` | Launch template user data failed | SSM into an instance, read `/var/log/cloud-init-output.log` |
 | `AccessDenied` on S3 | Path outside the platform buckets, or a missing KMS permission | Check the `genomic-data-access` policy in the batch module |
 | Job stuck in `RUNNABLE` | No capacity, `max_vcpus` reached, or the instance cannot reach ECS | Check the compute environment status and the Spot capacity in the AZ |
4. Rerun with `-resume`, which reuses completed tasks from the work bucket.

## Spend is higher than expected

1. `make costs` to see month-to-date spend by service.
2. Check for instances still running: `aws ec2 describe-instances --filters Name=tag:Project,Values=gpa Name=instance-state-name,Values=running`.
3. Check whether a NAT gateway was enabled by accident (`enable_nat`).
4. When in doubt, `make destroy`. Everything is reproducible from code.

## Rotate or recover

- **KMS key:** rotates every year automatically. Deleting it has a 7-day waiting period; cancel within that window if it was a mistake.
- **State:** restore an earlier version of `envs/dev/terraform.tfstate` from S3 versioning.
- **Stale lock:** `terraform force-unlock <ID>`, and only once you are sure no other run is active.

## Tear down

`make destroy`. In dev the buckets have `force_destroy = true`, so their contents are deleted too.
The bootstrap stack stays; destroy it last with `terraform -chdir=infra/bootstrap destroy`
after emptying the state bucket.

remove the

     backend block → terraform init -migrate-state (back to local) → destroy. Otherwise destroy would

     try to delete the bucket that holds its own state.