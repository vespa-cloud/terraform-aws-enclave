
output "bucket" {
  description = "ID of Vespa Cloud Enclave core dump bucket"
  value       = aws_s3_bucket.coredump.id
}
