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

variable "github_repo" {
  description = "GitHub repository allowed to assume the CI roles, as owner/name."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_repo))
    error_message = "github_repo must be owner/name, e.g. octo-org/my-repo (no 'github_repo=' prefix)."
  }
}
