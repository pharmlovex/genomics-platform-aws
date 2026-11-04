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
}
