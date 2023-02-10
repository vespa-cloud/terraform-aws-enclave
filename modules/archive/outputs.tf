
output "bucket" {
  description = "ID of Vespa Cloud Enclave archive bucket"
  value       = aws_s3_bucket.archive.id
}
