
variable "account" {
  description = "AWS account that contains Vespa Cloud Enclave"
  type        = string
}

variable "tenant_name" {
  description = "The tenant owner running Enclave account"
  type        = string
}

variable "secret_arns" {
  description = "List of Secrets Manager ARNs to make available for Vespa hosts."
  type        = list(string)
}

variable "kms_key_arns" {
  description = "Optional list of KMS key ARNs used by the secrets."
  type        = list(string)
  default     = []
}
