variable "name" {
  description = "Name prefix for database resources."
  type        = string
}

variable "subnet_ids" {
  description = "Isolated subnet IDs used by the database cluster."
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group attached to the database cluster."
  type        = string
}

variable "database_name" {
  description = "Initial PostgreSQL database name."
  type        = string
}

variable "master_username" {
  description = "Master PostgreSQL username."
  type        = string
  default     = "app_admin"
}

variable "snapshot_identifier" {
  description = "Optional snapshot ARN from which to restore the cluster."
  type        = string
  default     = null
  nullable    = true
}

variable "engine_version" {
  description = "Aurora PostgreSQL engine version."
  type        = string
  default     = "16.6"
}

variable "instance_count" {
  description = "Number of Aurora instances distributed across subnets."
  type        = number

  validation {
    condition     = var.instance_count >= 2
    error_message = "At least two database instances are required for high availability."
  }
}

variable "serverless_min_capacity" {
  description = "Minimum Aurora Serverless v2 capacity units."
  type        = number
}

variable "serverless_max_capacity" {
  description = "Maximum Aurora Serverless v2 capacity units."
  type        = number
}

variable "backup_retention_days" {
  description = "Number of days to retain automated backups."
  type        = number
}

variable "backup_schedule" {
  description = "AWS Backup schedule in EventBridge cron format."
  type        = string
  default     = "cron(0 3 * * ? *)"
}

variable "log_retention_days" {
  description = "CloudWatch retention period for PostgreSQL logs."
  type        = number
}

variable "log_kms_key_arn" {
  description = "KMS key used to encrypt PostgreSQL logs."
  type        = string
}

variable "deletion_protection" {
  description = "Prevent accidental deletion of the cluster."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot when deleting the cluster."
  type        = bool
  default     = false
}

variable "cross_region_backup_enabled" {
  description = "Copy AWS Backup recovery points to the DR region."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}