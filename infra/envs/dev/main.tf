terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }

  # Partial config: bucket and key come from backend.hcl (see backend.hcl.example).
  # use_lockfile = S3-native state locking (Terraform >= 1.10), no DynamoDB table.
  backend "s3" {
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = var.name
      Environment = "dev"
      ManagedBy   = "Terraform"
      Repository  = var.github_repo
    }
  }
}

locals {
  # Must match local.iam_path in infra/bootstrap so the CI apply role can manage these roles.
  iam_path = "/${var.name}/"
}

module "network" {
  source     = "../../modules/network"
  name       = var.name
  enable_nat = var.enable_nat
}

module "storage" {
  source        = "../../modules/storage"
  name          = var.name
  force_destroy = true # dev only: lets `make destroy` remove buckets that still hold objects
}

module "batch" {
  source            = "../../modules/batch"
  name              = var.name
  iam_path          = local.iam_path
  subnet_ids        = module.network.compute_subnet_ids
  security_group_id = module.network.compute_security_group_id
  bucket_arns       = module.storage.bucket_arns
  kms_key_arn       = module.storage.kms_key_arn
  max_vcpus         = var.max_vcpus
}

module "observability" {
  source             = "../../modules/observability"
  name               = var.name
  alert_email        = var.alert_email
  job_queue_arns     = [module.batch.spot_queue_arn]
  bucket_names       = module.storage.bucket_names
  monthly_budget_usd = var.monthly_budget_usd
}
