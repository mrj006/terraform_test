variable "project_name" {
  description = "Short name used to identify this workload."
  type        = string
  default     = "webservice"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project_name))
    error_message = "project_name must be 3-21 lowercase letters, digits, or hyphens."
  }
}

variable "aws_region" {
  description = "Primary AWS region."
  type        = string
}

variable "dr_region" {
  description = "AWS region used for disaster recovery copies."
  type        = string

  validation {
    condition     = var.dr_region != var.aws_region
    error_message = "dr_region must differ from aws_region."
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

variable "container_image" {
  description = "Immutable Linux ARM64 application image URI."
  type        = string
}

variable "activate_dns" {
  description = "Create the service alias record; disable while staging a DR deployment."
  type        = bool
  default     = true
}

variable "container_port" {
  description = "Port on which the application listens."
  type        = number
  default     = 8080
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

variable "additional_tags" {
  description = "Additional tags merged into every supported resource."
  type        = map(string)
  default     = {}
}