
variable "default_region" {
  description = "Region to default to when resources don't need to be in a specific region"
  type        = string
  default     = "us-east-1"
}

variable "is_cd" {
  description = "Whether this terraform part of the Vespa Cloud CI/CD pipeline"
  type        = bool
  default     = false
}

variable "tenant_name" {
  description = "The tenant owner running enclave account"
  type        = string
}
