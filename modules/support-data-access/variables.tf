variable "support_data_access_expires_at" {
  description = "RFC 3339 UTC timestamp when read access to encrypted heap dumps and native core dumps expires, e.g. 2026-07-01T00:00:00Z. All access granted by this module is automatically denied after this time. Leave unset (null) to grant no access at all."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.support_data_access_expires_at == null || can(formatdate("YYYY", var.support_data_access_expires_at)) && can(regex("Z$", var.support_data_access_expires_at))
    error_message = "Must be an RFC 3339 UTC timestamp ending in Z, e.g. 2026-07-01T00:00:00Z."
  }
}

variable "debug_instance_role_arn" {
  description = "ARN of the IAM role used by Vespa Cloud debug instances"
  type        = string

  validation {
    condition     = var.debug_instance_role_arn != null
    error_message = "The debug instance role ARN is required and must not be null."
  }
}
