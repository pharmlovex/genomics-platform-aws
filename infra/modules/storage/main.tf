# Three buckets with different lifecycles:
#   data    - raw inputs (BAM/FASTQ). Versioned; moves to cheaper tiers as it ages.
#   results - pipeline outputs and run reports. Versioned; tiered.
#   work    - Nextflow scratch. Not versioned; expires after a few days.
# All use one customer-managed KMS key with rotation, block public access, and
# deny any request that is not over TLS.

data "aws_caller_identity" "current" {}

locals {
  buckets = {
    data    = { versioned = true, scratch = false }
    results = { versioned = true, scratch = false }
    work    = { versioned = false, scratch = true }
  }
}

resource "aws_kms_key" "data" {
  description             = "${var.name} genomic data encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "data" {
  name          = "alias/${var.name}-data"
  target_key_id = aws_kms_key.data.key_id
}

resource "aws_s3_bucket" "this" {
  for_each      = local.buckets
  bucket        = "${var.name}-${each.key}-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_ownership_controls" "this" {
  for_each = aws_s3_bucket.this
  bucket   = each.value.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each                = aws_s3_bucket.this
  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = { for k, v in local.buckets : k => v if v.versioned }
  bucket   = aws_s3_bucket.this[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = aws_s3_bucket.this
  bucket   = each.value.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.data.arn
    }
    # S3 Bucket Keys cut KMS request costs by roughly 99% for many-object workloads.
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_policy" "tls_only" {
  for_each = aws_s3_bucket.this
  bucket   = each.value.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [each.value.arn, "${each.value.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
  depends_on = [aws_s3_bucket_public_access_block.this]
}

resource "aws_s3_bucket_lifecycle_configuration" "tiered" {
  for_each = { for k, v in local.buckets : k => v if !v.scratch }
  bucket   = aws_s3_bucket.this[each.key].id

  rule {
    id     = "tier-down"
    status = "Enabled"
    filter {}
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "scratch" {
  bucket = aws_s3_bucket.this["work"].id

  rule {
    id     = "expire-scratch"
    status = "Enabled"
    filter {}
    expiration {
      days = var.work_retention_days
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}
