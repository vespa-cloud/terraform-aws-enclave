output "role_arn" {
  description = "ARN of the role used to read encrypted heap dumps and native core dumps, or null when no access is granted"
  value       = one(aws_iam_role.support_data_read[*].arn)
}

output "trusted_principal_arn" {
  description = "ARN trusted to assume the dump-read role, or null when no access is granted"
  value       = var.support_data_access_expires_at == null ? null : var.debug_instance_role_arn
}
