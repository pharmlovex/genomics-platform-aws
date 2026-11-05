variable "name" {
  description = "Short project name used as a prefix for every resource."
  type        = string
  default     = "gpa"
}

variable "region" {
  description = "AWS region. eu-west-2 (London) keeps genomic data in the UK."
  type        = string
  default     = "eu-west-2"
}

variable "github_sub_prefix" {
  description = "OIDC sub prefix GitHub issues for this repo. Immutable form pins owner and repo by ID.Get it with: gh api repos/OWNER/REPO/actions/oidc/customization/sub --jq .sub_claim_prefix"
  type        = string

  validation {
    condition     = can(regex("^repo:[A-Za-z0-9-]+(@[0-9]+)?/[A-Za-z0-9._-]+(@[0-9]+)?$", var.github_sub_prefix))
    error_message = "github_sub_prefix must look like repo:owner@123/name@456 (or repo:owner/name)."
  }
}
