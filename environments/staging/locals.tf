locals {
  environment = "staging"
  name        = "${var.project_name}-${local.environment}"

  settings = {
    vpc_cidr                = "10.20.0.0/16"
    availability_zone_count = 3
    single_nat_gateway      = false
    task_cpu                = 512
    task_memory             = 1024
    desired_count           = 2
    minimum_count           = 2
    maximum_count           = 8
    database_instance_count = 2
    database_min_capacity   = 0.5
    database_max_capacity   = 8
    backup_retention_days   = 14
    log_retention_days      = 90
    deletion_protection     = true
    force_destroy           = false
    cross_region_dr_enabled = false
  }

  tags = merge(var.additional_tags, {
    Application = var.project_name
    Environment = "Stage"
    ManagedBy   = "Terraform"
    Service     = var.project_name
  })
}