output "url" {
  description = "Public HTTPS URL of the web service."
  value       = "https://${var.domain_name}"
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.this.name
}

output "task_role_arn" {
  description = "IAM role assumed by application tasks."
  value       = aws_iam_role.task.arn
}