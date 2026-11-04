# 1. Run pipeline tasks on AWS Batch rather than EKS

Status: accepted

## Context
Nextflow tasks are short-lived batch jobs: they need CPU and memory for minutes to hours,
then disappear. The platform has to scale to zero between runs, and an engineer should be able
to run it without operating a cluster.

## Options
- **EKS + Nextflow k8s executor.** Flexible and familiar. But the control plane costs about
  $73 a month even when idle, and it adds node groups, upgrades and add-ons to look after.
- **AWS Batch on EC2.** Managed queueing and scaling, scales to zero, native Spot support,
  first-class Nextflow executor. Batch itself has no charge.
- **AWS HealthOmics workflows.** Fully managed, but less control over infrastructure.
  Showing infrastructure is the point of this repo.

## Decision
Use AWS Batch with a Spot compute environment and an On-Demand fallback in the same queue.
Keep the Kubernetes path for on-prem (`-profile homelab`), so the same pipeline runs on both.

## Consequences
- Idle cost is close to zero, and Spot cuts compute cost substantially compared with On-Demand.
- Spot interruptions are expected. Nextflow's `maxSpotAttempts` and the On-Demand
  fallback handle them.
- Instances need the AWS CLI for Nextflow's S3 staging. The launch template installs it at
  boot, so no custom AMI pipeline is needed. Boot is slower; a baked AMI is a later optimisation.
