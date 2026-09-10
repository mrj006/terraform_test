locals {
  environment = "dev"
  name        = "${var.project_name}-${local.environment}"

  settings = {
    vpc_cidr                = "10.10.0.0/16"
    availability_zone_count = 2
    single_nat_gateway      = true
    task_cpu                = 256
    task_memory             = 512
    desired_count           = 2
    minimum_count           = 2
    maximum_count           = 4
    database_instance_count = 2
    database_min_capacity   = 0.5
    database_max_capacity   = 2
    backup_retention_days   = 7
    log_retention_days      = 30
    deletion_protection     = false
    force_destroy           = true
    cross_region_dr_enabled = false
  }

  tags = merge(var.additional_tags, {
    Application = var.project_name
    Environment = "Dev"
    ManagedBy   = "Terraform"
    Service     = var.project_name
  })
}