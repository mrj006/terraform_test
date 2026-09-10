variable "name" {
  description = "Name prefix for endpoint resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC in which to create interface endpoints."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for interface endpoint ENIs."
  type        = list(string)
}

variable "application_security_group_id" {
  description = "Security group whose tasks may use the endpoints."
  type        = string
}

variable "allowed_https_egress_cidrs" {
  description = "Explicit external IPv4 destinations needed by the application over TLS."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}