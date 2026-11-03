
output "bucket" {
  description = "ID of the Vespa Cloud Enclave bucket for heap dumps and native core dumps"
  value       = aws_s3_bucket.coredump.id
}
