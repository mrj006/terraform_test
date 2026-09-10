data "aws_region" "current" {}

locals {
  interface_services = toset([
    "ecr.api",
    "ecr.dkr",
    "logs",
    "secretsmanager",
  ])
}

resource "aws_security_group" "endpoints" {
  name        = "${var.name}-endpoints"
  description = "TLS access to private AWS API endpoints"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-endpoints" })
}

resource "aws_vpc_security_group_ingress_rule" "endpoints" {
  security_group_id            = aws_security_group.endpoints.id
  description                  = "TLS from application tasks"
  referenced_security_group_id = var.application_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "application_endpoints" {
  security_group_id            = var.application_security_group_id
  description                  = "TLS to private AWS API endpoints"
  referenced_security_group_id = aws_security_group.endpoints.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "application_external_https" {
  for_each = toset(var.allowed_https_egress_cidrs)

  security_group_id = var.application_security_group_id
  description       = "Approved external TLS dependency at ${each.value}"
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_services

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]

  tags = merge(var.tags, { Name = "${var.name}-${replace(each.value, ".", "-")}" })
}