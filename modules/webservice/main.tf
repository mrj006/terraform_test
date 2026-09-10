data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "operations_kms" {
  #checkov:skip=CKV_AWS_109:KMS key policies require Resource "*"; access is constrained by principals and encryption context.
  #checkov:skip=CKV_AWS_111:KMS key policies require Resource "*"; access is constrained by principals and encryption context.
  #checkov:skip=CKV_AWS_356:KMS key policies require Resource "*"; access is constrained by principals and encryption context.
  statement {
    sid       = "EnableAccountAdministration"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid = "AllowCloudWatchLogs"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*",
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.region}.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:*"]
    }
  }

  statement {
    sid = "AllowCloudWatchAlarmsToPublish"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*",
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_kms_key" "operations" {
  description             = "Encrypts ${var.name} logs and alarm notifications"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.operations_kms.json
  tags                    = var.tags
}

resource "aws_kms_alias" "operations" {
  name          = "alias/${var.name}-operations"
  target_key_id = aws_kms_key.operations.key_id
}

module "network" {
  source = "../network"

  name                    = var.name
  vpc_cidr                = var.settings.vpc_cidr
  availability_zone_count = var.settings.availability_zone_count
  single_nat_gateway      = var.settings.single_nat_gateway
  flow_log_retention_days = var.settings.log_retention_days
  log_kms_key_arn         = aws_kms_key.operations.arn
  tags                    = var.tags
}

module "storage" {
  source = "../storage"

  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

  name                = var.name
  bucket_name         = "${var.name}-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}-data"
  log_bucket_name     = "${var.name}-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}-logs"
  replication_enabled = var.settings.cross_region_dr_enabled
  force_destroy       = var.settings.force_destroy
  tags                = var.tags
}

module "security" {
  source = "../security"

  name                  = var.name
  vpc_id                = module.network.vpc_id
  vpc_cidr              = module.network.vpc_cidr
  container_port        = var.container_port
  database_port         = 5432
  allowed_ingress_cidrs = var.allowed_ingress_cidrs
  tags                  = var.tags
}

module "endpoints" {
  source = "../endpoints"

  name                          = var.name
  vpc_id                        = module.network.vpc_id
  subnet_ids                    = module.network.private_subnet_ids
  application_security_group_id = module.security.application_security_group_id
  allowed_https_egress_cidrs    = var.allowed_https_egress_cidrs
  tags                          = var.tags
}

module "database" {
  source = "../database"

  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

  name                        = var.name
  subnet_ids                  = module.network.database_subnet_ids
  security_group_id           = module.security.database_security_group_id
  database_name               = replace(var.project_name, "-", "_")
  snapshot_identifier         = var.database_snapshot_identifier
  instance_count              = var.settings.database_instance_count
  serverless_min_capacity     = var.settings.database_min_capacity
  serverless_max_capacity     = var.settings.database_max_capacity
  backup_retention_days       = var.settings.backup_retention_days
  log_retention_days          = var.settings.log_retention_days
  log_kms_key_arn             = aws_kms_key.operations.arn
  deletion_protection         = var.settings.deletion_protection
  skip_final_snapshot         = !var.settings.deletion_protection
  cross_region_backup_enabled = var.settings.cross_region_dr_enabled
  tags                        = var.tags
}

resource "aws_sns_topic" "alarms" {
  name              = "${var.name}-alarms"
  kms_master_key_id = aws_kms_key.operations.arn
  tags              = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alarm_email == null ? 0 : 1

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

module "service" {
  source = "../service"

  name                            = var.name
  vpc_id                          = module.network.vpc_id
  public_subnet_ids               = module.network.public_subnet_ids
  private_subnet_ids              = module.network.private_subnet_ids
  load_balancer_security_group_id = module.security.load_balancer_security_group_id
  application_security_group_id   = module.security.application_security_group_id
  container_name                  = local.container_name
  container_port                  = var.container_port
  container_definitions           = local.container_definitions
  task_cpu                        = var.settings.task_cpu
  task_memory                     = var.settings.task_memory
  desired_count                   = var.settings.desired_count
  minimum_count                   = var.settings.minimum_count
  maximum_count                   = var.settings.maximum_count
  health_check_path               = var.health_check_path
  domain_name                     = var.domain_name
  hosted_zone_id                  = var.hosted_zone_id
  activate_dns                    = var.activate_dns
  log_bucket_name                 = module.storage.log_bucket_name
  application_bucket_arn          = module.storage.application_bucket_arn
  application_kms_key_arn         = module.storage.application_kms_key_arn
  database_secret_arn             = module.database.master_secret_arn
  database_kms_key_arn            = module.database.kms_key_arn
  log_retention_days              = var.settings.log_retention_days
  log_kms_key_arn                 = aws_kms_key.operations.arn
  deletion_protection             = var.settings.deletion_protection
  alarm_actions                   = [aws_sns_topic.alarms.arn]
  tags                            = var.tags

  depends_on = [module.endpoints, module.storage]
}