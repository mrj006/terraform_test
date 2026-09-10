resource "aws_kms_key" "database" {
  description             = "Encrypts ${var.name} Aurora storage and credentials"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_kms_alias" "database" {
  name          = "alias/${var.name}-database"
  target_key_id = aws_kms_key.database.key_id
}

resource "aws_db_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, { Name = var.name })
}

resource "aws_rds_cluster_parameter_group" "this" {
  name        = var.name
  family      = "aurora-postgresql16"
  description = "Secure PostgreSQL defaults for ${var.name}"
  tags        = var.tags

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }
}

resource "aws_cloudwatch_log_group" "postgresql" {
  name              = "/aws/rds/cluster/${var.name}/postgresql"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_kms_key_arn
  tags              = var.tags
}

resource "aws_rds_cluster" "this" {
  cluster_identifier  = var.name
  engine              = "aurora-postgresql"
  engine_mode         = "provisioned"
  engine_version      = var.engine_version
  snapshot_identifier = var.snapshot_identifier

  database_name                       = var.snapshot_identifier == null ? var.database_name : null
  master_username                     = var.snapshot_identifier == null ? var.master_username : null
  manage_master_user_password         = true
  master_user_secret_kms_key_id       = aws_kms_key.database.arn
  iam_database_authentication_enabled = true

  db_subnet_group_name            = aws_db_subnet_group.this.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name
  vpc_security_group_ids          = [var.security_group_id]
  port                            = 5432

  storage_encrypted               = true
  kms_key_id                      = aws_kms_key.database.arn
  backup_retention_period         = var.backup_retention_days
  preferred_backup_window         = "03:00-04:00"
  preferred_maintenance_window    = "sun:05:00-sun:06:00"
  copy_tags_to_snapshot           = true
  deletion_protection             = var.deletion_protection
  skip_final_snapshot             = var.skip_final_snapshot
  final_snapshot_identifier       = var.skip_final_snapshot ? null : "${var.name}-final-snapshot"
  enabled_cloudwatch_logs_exports = ["postgresql"]

  serverlessv2_scaling_configuration {
    min_capacity = var.serverless_min_capacity
    max_capacity = var.serverless_max_capacity
  }

  tags = var.tags

  depends_on = [aws_cloudwatch_log_group.postgresql]
}

data "aws_iam_policy_document" "monitoring_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitoring" {
  name               = "${var.name}-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_rds_cluster_instance" "this" {
  count = var.instance_count

  identifier                      = "${var.name}-${count.index + 1}"
  cluster_identifier              = aws_rds_cluster.this.id
  instance_class                  = "db.serverless"
  engine                          = aws_rds_cluster.this.engine
  engine_version                  = aws_rds_cluster.this.engine_version
  db_subnet_group_name            = aws_db_subnet_group.this.name
  publicly_accessible             = false
  auto_minor_version_upgrade      = true
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.monitoring.arn
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.database.arn
  copy_tags_to_snapshot           = true
  tags                            = var.tags
}

resource "aws_backup_vault" "primary" {
  name        = "${var.name}-database"
  kms_key_arn = aws_kms_key.database.arn
  tags        = var.tags
}

resource "aws_kms_key" "backup_dr" {
  provider = aws.dr
  count    = var.cross_region_backup_enabled ? 1 : 0

  description             = "Encrypts ${var.name} database recovery points"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_backup_vault" "dr" {
  provider = aws.dr
  count    = var.cross_region_backup_enabled ? 1 : 0

  name        = "${var.name}-database-dr"
  kms_key_arn = aws_kms_key.backup_dr[0].arn
  tags        = merge(var.tags, { DisasterRecovery = "true" })
}

resource "aws_backup_plan" "this" {
  name = "${var.name}-database"

  rule {
    rule_name                = "daily-continuous-backup"
    target_vault_name        = aws_backup_vault.primary.name
    schedule                 = var.backup_schedule
    start_window             = 60
    completion_window        = 360
    enable_continuous_backup = true

    lifecycle {
      delete_after = var.backup_retention_days
    }

    dynamic "copy_action" {
      for_each = var.cross_region_backup_enabled ? [1] : []

      content {
        destination_vault_arn = aws_backup_vault.dr[0].arn

        lifecycle {
          delete_after = var.backup_retention_days
        }
      }
    }
  }

  tags = var.tags
}

data "aws_iam_policy_document" "backup_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  name               = "${var.name}-backup"
  assume_role_policy = data.aws_iam_policy_document.backup_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_backup_selection" "this" {
  iam_role_arn = aws_iam_role.backup.arn
  name         = "${var.name}-database"
  plan_id      = aws_backup_plan.this.id
  resources    = [aws_rds_cluster.this.arn]
}