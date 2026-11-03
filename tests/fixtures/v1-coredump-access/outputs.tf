output "role_arn" {
  description = "ARN of the core dump read role assumed by Vespa Cloud debug instances, or null when no access is granted"
  value       = one(aws_iam_role.coredump_read[*].arn)
}

# Test-only observations. The v1.10.0 resource graph above is unchanged.
output "role_name" {
  value = one(aws_iam_role.coredump_read[*].name)
}

output "policy_name" {
  value = one(aws_iam_policy.coredump_read[*].name)
}
