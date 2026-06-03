
output "role_arn" {
  description = "ARN of the core dump read role assumed by Vespa Cloud debug instances"
  value       = aws_iam_role.coredump_read.arn
}
