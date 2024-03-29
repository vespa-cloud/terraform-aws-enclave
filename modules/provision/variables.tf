
variable "account" {
  description = "AWS account that contains Vespa Cloud Enclave"
  type        = string
}

variable "vespa_cloud_account" {
  description = "The account the Vespa Cloud provisioner resides in"
  type        = string
}

variable "tenant_name" {
  description = "The tenant owner running Enclave account"
  type        = string
}

variable "is_cd" {
  description = "Whether this terraform part of the Vespa Cloud CI/CD pipeline"
  type        = bool
}
