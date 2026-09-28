output "role_arn" {
  description = "ARN of the support-data read role assumed by Vespa Cloud debug instances, or null when no access is granted"
  value       = one(aws_iam_role.support_data_read[*].arn)
}

output "trusted_principal_arn" {
  description = "ARN trusted to assume the support-data read role, or null when no access is granted"
  value       = var.support_data_access_expires_at == null ? null : var.debug_instance_role_arn
}
