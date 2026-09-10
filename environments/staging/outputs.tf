output "service_url" {
  description = "HTTPS URL of the deployed web service."
  value       = module.webservice.service_url
}

output "application_bucket_name" {
  description = "S3 bucket available to the web service task role."
  value       = module.webservice.application_bucket_name
}

output "disaster_recovery_bucket_name" {
  description = "Cross-region replica bucket when disaster recovery is enabled."
  value       = module.webservice.disaster_recovery_bucket_name
}

output "database_endpoint" {
  description = "Private Aurora writer endpoint."
  value       = module.webservice.database_endpoint
}

output "alarm_topic_arn" {
  description = "SNS topic receiving operational alarms."
  value       = module.webservice.alarm_topic_arn
}