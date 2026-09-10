output "application_bucket_arn" {
  description = "ARN of the application data bucket."
  value       = aws_s3_bucket.application.arn
}

output "application_bucket_name" {
  description = "Name of the application data bucket."
  value       = aws_s3_bucket.application.id
}

output "application_kms_key_arn" {
  description = "ARN of the key encrypting application objects."
  value       = aws_kms_key.application.arn
}

output "log_bucket_name" {
  description = "Name of the load balancer log bucket."
  value       = aws_s3_bucket.logs.id
}

output "replica_bucket_name" {
  description = "Name of the disaster recovery bucket, when enabled."
  value       = try(aws_s3_bucket.replica[0].id, null)
}