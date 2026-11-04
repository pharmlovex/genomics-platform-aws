# AWS Batch for Nextflow tasks: a Spot compute environment (preferred) and an
# On-Demand one (fallback), both scaling to zero when idle. Uses the Batch
# service-linked role, so no service role is managed here. Instances get SSM
# access instead of SSH. See docs/adr/0001 for why Batch rather than EKS.

data "aws_partition" "current" {}

# ------------------------------------------------------------ instance role
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "${var.name}-batch-instance"
  path               = var.iam_path
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_role_policy_attachment" "ecs" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Least privilege: read inputs, write results and scratch, use the data key.
data "aws_iam_policy_document" "data_access" {
  statement {
    sid       = "ListBuckets"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [var.bucket_arns["data"], var.bucket_arns["results"], var.bucket_arns["work"]]
  }
  statement {
    sid       = "ReadInputs"
    actions   = ["s3:GetObject"]
    resources = ["${var.bucket_arns["data"]}/*"]
  }
  statement {
    sid = "ReadWriteOutputs"
    actions = [
      "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
      "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts",
    ]
    resources = ["${var.bucket_arns["results"]}/*", "${var.bucket_arns["work"]}/*"]
  }
  statement {
    sid       = "UseDataKey"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "data_access" {
  name   = "genomic-data-access"
  role   = aws_iam_role.instance.id
  policy = data.aws_iam_policy_document.data_access.json
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.name}-batch-instance"
  path = var.iam_path
  role = aws_iam_role.instance.name
}

# ------------------------------------------------------------ launch template
# Nextflow stages files in and out of S3 with the AWS CLI on the host, which it
# mounts into each task container. Installed with Miniforge (conda-forge, no
# Anaconda licence terms) at boot, so no custom AMI is needed.
resource "aws_launch_template" "batch" {
  name_prefix = "${var.name}-batch-"
  user_data   = base64encode(file("${path.module}/user-data.mime"))

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.root_volume_gb
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 2          # containers can still reach credentials
  }
}

# ------------------------------------------------------------ compute environments
locals {
  compute_envs = {
    spot = {
      type     = "SPOT"
      strategy = "SPOT_PRICE_CAPACITY_OPTIMIZED"
    }
    ondemand = {
      type     = "EC2"
      strategy = "BEST_FIT_PROGRESSIVE"
    }
  }
}

resource "aws_batch_compute_environment" "this" {
  for_each = local.compute_envs
  # A prefix lets create_before_destroy replace an environment without a name clash.
  name_prefix = "${var.name}-${each.key}-"
  type        = "MANAGED"

  compute_resources {
    type                = each.value.type
    allocation_strategy = each.value.strategy
    bid_percentage      = each.value.type == "SPOT" ? 100 : null
    min_vcpus           = 0
    max_vcpus           = var.max_vcpus
    instance_type       = var.instance_types
    instance_role       = aws_iam_instance_profile.instance.arn
    subnets             = var.subnet_ids
    security_group_ids  = [var.security_group_id]

    launch_template {
      launch_template_id = aws_launch_template.batch.id
      version            = aws_launch_template.batch.latest_version
    }

    ec2_configuration {
      image_type = "ECS_AL2023"
    }

    tags = { Name = "${var.name}-batch-${each.key}" }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_batch_job_queue" "spot" {
  name     = "${var.name}-spot"
  state    = "ENABLED"
  priority = 10

  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.this["spot"].arn
  }
  compute_environment_order {
    order               = 2
    compute_environment = aws_batch_compute_environment.this["ondemand"].arn
  }
}

resource "aws_batch_job_queue" "ondemand" {
  name     = "${var.name}-ondemand"
  state    = "ENABLED"
  priority = 20

  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.this["ondemand"].arn
  }
}

resource "aws_cloudwatch_log_group" "batch_jobs" {
  # Batch writes job logs here. Created up front so retention is managed.
  name              = "/aws/batch/job"
  retention_in_days = var.log_retention_days
}
