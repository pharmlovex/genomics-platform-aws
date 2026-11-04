variable "name" {
  type = string
}

variable "alert_email" {
  description = "Where failure and budget alerts go. Confirm the SNS subscription email after the first apply."
  type        = string
}

variable "job_queue_arns" {
  type = list(string)
}

variable "bucket_names" {
  description = "Map of bucket purpose to name, for the dashboard."
  type        = map(string)
}

variable "monthly_budget_usd" {
  type    = number
  default = 20
}
