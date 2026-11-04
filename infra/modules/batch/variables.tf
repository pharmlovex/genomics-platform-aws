variable "name" {
  type = string
}

variable "iam_path" {
  description = "IAM path for roles. Must match the path the CI apply role may manage."
  type        = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "bucket_arns" {
  description = "Map with keys data, results and work."
  type        = map(string)
}

variable "kms_key_arn" {
  type = string
}

variable "instance_types" {
  description = "Instance families Batch may choose from."
  type        = list(string)
  default     = ["c6i", "m6i", "r6i", "c5", "m5"]
}

variable "max_vcpus" {
  description = "Upper bound on concurrent vCPUs. Also a hard cost ceiling."
  type        = number
  default     = 32
}

variable "root_volume_gb" {
  type    = number
  default = 100
}

variable "log_retention_days" {
  type    = number
  default = 14
}
