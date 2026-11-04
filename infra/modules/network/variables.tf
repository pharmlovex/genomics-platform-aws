variable "name" {
  type = string
}

variable "cidr" {
  type    = string
  default = "10.40.0.0/16"
}

variable "az_count" {
  description = "How many availability zones to spread compute across."
  type        = number
  default     = 2
}

variable "enable_nat" {
  description = "Put compute in private subnets behind a NAT gateway (costs about $35/month idle)."
  type        = bool
  default     = false
}
