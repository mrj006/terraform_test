variable "name" {
  description = "Name prefix for network resources."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR assigned to the VPC."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR."
  }
}

variable "availability_zone_count" {
  description = "Number of availability zones to use."
  type        = number

  validation {
    condition     = var.availability_zone_count >= 2 && var.availability_zone_count <= 3
    error_message = "availability_zone_count must be two or three."
  }
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway to reduce non-production cost."
  type        = bool
  default     = false
}

variable "flow_log_retention_days" {
  description = "CloudWatch retention period for VPC flow logs."
  type        = number
  default     = 90
}

variable "log_kms_key_arn" {
  description = "KMS key used to encrypt VPC flow logs."
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}