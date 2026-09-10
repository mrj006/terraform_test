module "webservice" {
  source = "../../modules/webservice"

  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

  name                         = local.name
  project_name                 = var.project_name
  environment                  = local.environment
  settings                     = local.settings
  domain_name                  = var.domain_name
  hosted_zone_id               = var.hosted_zone_id
  activate_dns                 = var.activate_dns
  container_image              = var.container_image
  container_port               = var.container_port
  health_check_path            = var.health_check_path
  database_snapshot_identifier = var.database_snapshot_identifier
  allowed_ingress_cidrs        = var.allowed_ingress_cidrs
  allowed_https_egress_cidrs   = var.allowed_https_egress_cidrs
  alarm_email                  = var.alarm_email
  tags                         = local.tags
}