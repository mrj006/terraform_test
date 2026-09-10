locals {
  environment = "prod"
  name        = "${var.project_name}-${local.environment}"

  settings = {
    vpc_cidr                = "10.30.0.0/16"
    availability_zone_count = 3
    single_nat_gateway      = false
    task_cpu                = 1024
    task_memory             = 2048
    desired_count           = 3
    minimum_count           = 3
    maximum_count           = 20
    database_instance_count = 3
    database_min_capacity   = 2
    database_max_capacity   = 32
    backup_retention_days   = 35
    log_retention_days      = 365
    deletion_protection     = true
    force_destroy           = false
    cross_region_dr_enabled = true
  }

  tags = merge(var.additional_tags, {
    Application = var.project_name
    Environment = "Prod"
    ManagedBy   = "Terraform"
    Service     = var.project_name
  })
}