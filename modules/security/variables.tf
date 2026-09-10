variable "name" {
  description = "Name prefix for security groups."
  type        = string
}

variable "vpc_id" {
  description = "VPC in which to create security groups."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR used to reach the Amazon-provided DNS resolver."
  type        = string
}

variable "container_port" {
  description = "Port exposed by the web service."
  type        = number
}

variable "database_port" {
  description = "Port exposed by the database."
  type        = number
  default     = 5432
}

variable "allowed_ingress_cidrs" {
  description = "IPv4 CIDRs allowed to reach the public load balancer."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}