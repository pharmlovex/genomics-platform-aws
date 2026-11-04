variable "name" {
  type = string
}

variable "work_retention_days" {
  description = "Days before Nextflow scratch files in the work bucket are deleted."
  type        = number
  default     = 3
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete non-empty buckets. Keep true for a demo account only."
  type        = bool
  default     = false
}
