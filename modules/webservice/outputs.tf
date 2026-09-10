output "service_url" {
  description = "HTTPS URL of the deployed web service."
  value       = module.service.url
}

output "application_bucket_name" {
  description = "S3 bucket available to the web service task role."
  value       = module.storage.application_bucket_name
}

output "disaster_recovery_bucket_name" {
  description = "Cross-region replica bucket created when disaster recovery is enabled."
  value       = module.storage.replica_bucket_name
}

output "database_endpoint" {
  description = "Private Aurora writer endpoint."
  value       = module.database.endpoint
}

output "alarm_topic_arn" {
  description = "SNS topic receiving operational alarms."
  value       = aws_sns_topic.alarms.arn
}