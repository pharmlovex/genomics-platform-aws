# Day-to-day commands. Run `make help` for the list.
SHELL   := /bin/bash
ENV_DIR := infra/envs/dev
PIPE    := pipelines/bam-qc
TF      := terraform -chdir=$(ENV_DIR)
OUT      = $(shell $(TF) output -raw $(1))

.PHONY: help bootstrap init plan apply destroy fmt test upload-test-data run-local run-aws costs

help:            ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  %-18s %s\n", $$1, $$2}'

bootstrap:       ## One-off: state bucket + GitHub OIDC roles (needs admin creds and GITHUB_REPO=owner/name)
	terraform -chdir=infra/bootstrap init
	terraform -chdir=infra/bootstrap apply -var="github_sub_prefix=$$(gh api repos/$(GITHUB_REPO)/actions/oidc/customization/sub --jq .sub_claim_prefix)"

init:            ## Init the dev stack against the remote state (needs infra/envs/dev/backend.hcl)
	$(TF) init -backend-config=backend.hcl

plan:            ## Plan the dev stack
	$(TF) plan

apply:           ## Apply the dev stack (CI normally does this)
	$(TF) apply

destroy:         ## Tear the dev stack down to stop all charges
	$(TF) destroy

fmt:             ## Format all Terraform
	terraform fmt -recursive infra

test:            ## Run nf-test locally with Docker
	cd $(PIPE) && nf-test test

run-local:       ## Run the pipeline locally on the public test BAM
	cd $(PIPE) && nextflow run main.nf -profile test --outdir results-local

upload-test-data: ## Copy the test BAM into the data bucket and write an AWS samplesheet
	curl -fsSL -o /tmp/test.bam https://raw.githubusercontent.com/nf-core/test-datasets/modules/data/genomics/homo_sapiens/illumina/bam/test.paired_end.sorted.bam
	curl -fsSL -o /tmp/test.bam.bai https://raw.githubusercontent.com/nf-core/test-datasets/modules/data/genomics/homo_sapiens/illumina/bam/test.paired_end.sorted.bam.bai
	aws s3 cp /tmp/test.bam     s3://$(call OUT,data_bucket)/test/test.paired_end.sorted.bam
	aws s3 cp /tmp/test.bam.bai s3://$(call OUT,data_bucket)/test/test.paired_end.sorted.bam.bai
	printf 'sample,bam,bai\ntest_paired,s3://%s/test/test.paired_end.sorted.bam,s3://%s/test/test.paired_end.sorted.bam.bai\n' \
	  $(call OUT,data_bucket) $(call OUT,data_bucket) > $(PIPE)/assets/samplesheet.aws.csv

run-aws:         ## Run the pipeline on AWS Batch (Spot queue)
	cd $(PIPE) && nextflow run main.nf -profile awsbatch \
	  --samplesheet assets/samplesheet.aws.csv \
	  --batch_queue $(call OUT,spot_queue) \
	  --work_bucket $(call OUT,work_bucket) \
		--alert_topic $(call OUT,alerts_topic_arn) \
	  --outdir s3://$(call OUT,results_bucket)/bam-qc/$$(date +%Y%m%d-%H%M%S)
		

costs:           ## Month-to-date cost by service (needs Cost Explorer enabled)
	aws ce get-cost-and-usage --time-period Start=$$(date +%Y-%m-01),End=$$(date -d tomorrow +%Y-%m-%d) \
	  --granularity MONTHLY --metrics UnblendedCost --group-by Type=DIMENSION,Key=SERVICE \
	  --query 'ResultsByTime[0].Groups[?Metrics.UnblendedCost.Amount>`0.01`].[Keys[0],Metrics.UnblendedCost.Amount]' --output table
