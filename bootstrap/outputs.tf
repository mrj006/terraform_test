output "state_bucket_name" {
  description = "S3 bucket shared by the environment backend configurations."
  value       = aws_s3_bucket.state.id
}

output "state_kms_key_arn" {
  description = "Primary KMS key shared by all environment state objects."
  value       = aws_kms_key.state.arn
}

output "state_replica_bucket_name" {
  description = "S3 bucket used as the backend during a primary-region disaster."
  value       = aws_s3_bucket.state_replica.id
}

output "state_replica_kms_key_arn" {
  description = "KMS key protecting the replicated state backend."
  value       = aws_kms_key.state_replica.arn
}