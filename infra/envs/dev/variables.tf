variable "name" {
  type    = string
  default = "gpa"
}

variable "region" {
  type    = string
  default = "eu-west-2"
}

variable "github_repo" {
  description = "owner/name, used for tagging."
  type        = string
}

variable "alert_email" {
  type = string
}

variable "enable_nat" {
  type    = bool
  default = false
}

variable "max_vcpus" {
  type    = number
  default = 32
}

variable "monthly_budget_usd" {
  type    = number
  default = 20
}
