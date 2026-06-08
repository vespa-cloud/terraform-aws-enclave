
variable "read_access_expires_at" {
  description = "RFC 3339 UTC timestamp when core dump read access expires, e.g. 2026-07-01T00:00:00Z. All access granted by this module is automatically denied after this time. Leave unset (null) to grant no access at all."
  type        = string
  default     = null
  nullable    = true
  validation {
    condition     = var.read_access_expires_at == null || can(formatdate("YYYY", var.read_access_expires_at)) && can(regex("Z$", var.read_access_expires_at))
    error_message = "Must be an RFC 3339 UTC timestamp ending in Z, e.g. 2026-07-01T00:00:00Z."
  }
}

variable "debug_instance_role_arn" {
  description = "ARN of the IAM role used by Vespa Cloud debug instances"
  type        = string
  default     = "arn:aws:iam::061361823659:role/vespa-debug-instance"
}
