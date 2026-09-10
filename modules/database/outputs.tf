output "endpoint" {
  description = "Writer endpoint for the Aurora cluster."
  value       = aws_rds_cluster.this.endpoint
}

output "reader_endpoint" {
  description = "Read-only endpoint for the Aurora cluster."
  value       = aws_rds_cluster.this.reader_endpoint
}

output "database_name" {
  description = "Name of the initial PostgreSQL database."
  value       = aws_rds_cluster.this.database_name
}

output "master_secret_arn" {
  description = "Secrets Manager ARN containing the managed master credentials."
  value       = aws_rds_cluster.this.master_user_secret[0].secret_arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key protecting database data and credentials."
  value       = aws_kms_key.database.arn
}

output "cluster_arn" {
  description = "ARN of the Aurora cluster."
  value       = aws_rds_cluster.this.arn
}