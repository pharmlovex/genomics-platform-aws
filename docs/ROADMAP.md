# Roadmap

Each milestone ends with something working and measurable. Tick boxes as you go and record
the real numbers.

## 1. Local pipeline
- [ ] `make run-local` passes; open `results-local/pipeline_info/report.html`
- [ ] `make test` (nf-test) passes
- [ ] Push to GitHub; the `pipeline` workflow is green

The pipeline is tested in CI against public nf-core data before it ever reaches AWS.

## 2. Bootstrap and secure CI
- [ ] `make bootstrap` in a fresh AWS account. Turn on MFA for root and use an admin IAM Identity Center user, not root.
- [ ] GitHub secrets and variables set; `dev` environment with a required reviewer
- [ ] Open a PR that changes a tag. The plan appears as a PR comment.

There are no AWS keys in GitHub. CI uses OIDC, pull requests can only plan, and only the
protected main-branch environment can apply.

## 3. Deploy the platform
- [ ] Merge to main; the `apply` job deploys the dev stack
- [ ] Confirm the SNS email subscription
- [ ] `checkov` and `tflint` pass, with every skip justified
- [ ] Open the CloudWatch dashboard (link from `terraform output dashboard`)

## 4. Run genomics on Batch
- [ ] `make upload-test-data && make run-aws` succeeds
- [ ] Record: wall time, number of tasks, instance types Batch chose, cost (Cost Explorer next day)
- [ ] Break something on purpose, for example a bad BAM path, and confirm the failure email arrives
- [ ] Scale test: generate 20–50 samples (copies or downsampled BAMs) and run them. Record throughput and cost per sample.

## 5. Write it up
- [ ] Update the README Status section with measured numbers
- [ ] Add a screenshot of the dashboard and of a Nextflow timeline to `docs/`
- [ ] `make destroy` and confirm the bill stops (check again the next day)

## Stretch goals
- [ ] **Hybrid:** run `-profile homelab` on the Talos cluster and write an ADR on when to burst from on-prem to AWS
- [ ] **HPC:** add an AWS ParallelCluster (Slurm) or Seqera Platform compute environment
- [ ] **Security:** VPC flow logs, CloudTrail S3 data events for the data bucket, default security group lockdown (removes three Checkov skips)
- [ ] **Containers:** build the image in CI, push it to ECR with scan-on-push, and pin it by digest
- [ ] **Policy as code:** an OPA/conftest rule that fails the plan if any bucket is missing encryption
- [ ] **ML infrastructure:** a GPU compute environment (g5) behind its own queue
- [ ] **CI hardening:** apply the exact reviewed plan file; bump Node 20 actions; pin the runner image
