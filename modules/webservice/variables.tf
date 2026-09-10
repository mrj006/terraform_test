variable "name" {
  description = "Name prefix for workload resources."
  type        = string
}

variable "project_name" {
  description = "Short name identifying the workload."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

variable "settings" {
  description = "Environment-specific capacity, retention, and resilience settings."
  type = object({
    vpc_cidr                = string
    availability_zone_count = number
    single_nat_gateway      = bool
    task_cpu                = number
    task_memory             = number
    desired_count           = number
    minimum_count           = number
    maximum_count           = number
    database_instance_count = number
    database_min_capacity   = number
    database_max_capacity   = number
    backup_retention_days   = number
    log_retention_days      = number
    deletion_protection     = bool
    force_destroy           = bool
    cross_region_dr_enabled = bool
  })

  validation {
    condition     = var.settings.minimum_count <= var.settings.desired_count && var.settings.desired_count <= var.settings.maximum_count
    error_message = "minimum_count, desired_count, and maximum_count must be ordered from lowest to highest."
  }

  validation {
    condition     = var.settings.database_min_capacity <= var.settings.database_max_capacity
    error_message = "database_min_capacity must not exceed database_max_capacity."
  }
}

variable "domain_name" {
  description = "Fully qualified public DNS name for the web service."
  type        = string
}

variable "hosted_zone_id" {
  description = "Route 53 public hosted zone ID containing domain_name."
  type        = string
}

variable "activate_dns" {
  description = "Create the service alias record; disable while staging a DR deployment."
  type        = bool
  default     = true
}

variable "container_image" {
  description = "Immutable Linux ARM64 application image URI."
  type        = string
}

variable "container_port" {
  description = "Port on which the application listens."
  type        = number
  default     = 8080

  validation {
    condition     = var.container_port >= 1024 && var.container_port <= 65535
    error_message = "container_port must be an unprivileged TCP port."
  }
}

variable "health_check_path" {
  description = "Unauthenticated HTTP endpoint used for load balancer health checks."
  type        = string
  default     = "/health"
}

variable "database_snapshot_identifier" {
  description = "Optional RDS snapshot ARN from which to restore during disaster recovery."
  type        = string
  default     = null
  nullable    = true
}

variable "allowed_ingress_cidrs" {
  description = "IPv4 CIDRs allowed to reach the public service."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_https_egress_cidrs" {
  description = "Explicit external IPv4 destinations needed by the application over TLS."
  type        = list(string)
  default     = []
}

variable "alarm_email" {
  description = "Optional email address subscribed to operational alarms."
  type        = string
  default     = null
  nullable    = true
}

variable "tags" {
  description = "Tags applied to all supported workload resources."
  type        = map(string)
}