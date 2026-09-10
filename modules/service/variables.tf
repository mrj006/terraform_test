variable "name" {
  description = "Name prefix for service resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC containing the load balancer and tasks."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the load balancer."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks."
  type        = list(string)
}

variable "load_balancer_security_group_id" {
  description = "Security group attached to the load balancer."
  type        = string
}

variable "application_security_group_id" {
  description = "Security group attached to ECS tasks."
  type        = string
}

variable "container_name" {
  description = "Name of the essential application container."
  type        = string
}

variable "container_port" {
  description = "Port exposed by the application container."
  type        = number
}

variable "container_definitions" {
  description = "Rendered ECS container definitions JSON."
  type        = string
}

variable "task_cpu" {
  description = "Fargate task CPU units."
  type        = number
}

variable "task_memory" {
  description = "Fargate task memory in MiB."
  type        = number
}

variable "desired_count" {
  description = "Desired ECS task count."
  type        = number
}

variable "minimum_count" {
  description = "Minimum ECS task count."
  type        = number
}

variable "maximum_count" {
  description = "Maximum ECS task count."
  type        = number
}

variable "health_check_path" {
  description = "HTTP health check path exposed by the application."
  type        = string
  default     = "/health"
}

variable "domain_name" {
  description = "Fully qualified DNS name for the web service."
  type        = string
}

variable "hosted_zone_id" {
  description = "Route 53 public hosted zone ID for the domain."
  type        = string
}

variable "activate_dns" {
  description = "Create the public service alias record."
  type        = bool
  default     = true
}

variable "log_bucket_name" {
  description = "S3 bucket receiving load balancer access logs."
  type        = string
}

variable "application_bucket_arn" {
  description = "ARN of the application data bucket."
  type        = string
}

variable "application_kms_key_arn" {
  description = "KMS key protecting application objects."
  type        = string
}

variable "database_secret_arn" {
  description = "Secrets Manager ARN containing database credentials."
  type        = string
}

variable "database_kms_key_arn" {
  description = "KMS key protecting database credentials."
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch application log retention period."
  type        = number
}

variable "log_kms_key_arn" {
  description = "KMS key used to encrypt application logs."
  type        = string
}

variable "deletion_protection" {
  description = "Prevent accidental deletion of the load balancer."
  type        = bool
  default     = true
}

variable "alarm_actions" {
  description = "ARNs notified by CloudWatch alarms."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}