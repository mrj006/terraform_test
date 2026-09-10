output "load_balancer_security_group_id" {
  description = "Security group ID for the public load balancer."
  value       = aws_security_group.load_balancer.id
}

output "application_security_group_id" {
  description = "Security group ID for ECS tasks."
  value       = aws_security_group.application.id
}

output "database_security_group_id" {
  description = "Security group ID for the database."
  value       = aws_security_group.database.id
}