variable "name" {
  description = "Name prefix for storage resources."
  type        = string
}

variable "bucket_name" {
  description = "Globally unique name for the application bucket."
  type        = string
}

variable "log_bucket_name" {
  description = "Globally unique name for the load balancer log bucket."
  type        = string
}

variable "replication_enabled" {
  description = "Replicate application objects to the disaster recovery region."
  type        = bool
  default     = false
}

variable "force_destroy" {
  description = "Permit bucket destruction when objects remain."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}