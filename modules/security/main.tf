resource "aws_security_group" "load_balancer" {
  name        = "${var.name}-alb"
  description = "Public TLS ingress to the application load balancer"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-alb" })
}

resource "aws_vpc_security_group_ingress_rule" "load_balancer_https" {
  for_each = toset(var.allowed_ingress_cidrs)

  security_group_id = aws_security_group.load_balancer.id
  description       = "HTTPS from ${each.value}"
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_security_group" "application" {
  name        = "${var.name}-application"
  description = "Ingress from the load balancer to ECS tasks"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-application" })
}

resource "aws_vpc_security_group_ingress_rule" "application" {
  security_group_id            = aws_security_group.application.id
  description                  = "Web traffic from the load balancer"
  referenced_security_group_id = aws_security_group.load_balancer.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "load_balancer" {
  security_group_id            = aws_security_group.load_balancer.id
  description                  = "Health checks and web traffic to ECS tasks"
  referenced_security_group_id = aws_security_group.application.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

resource "aws_security_group" "database" {
  name        = "${var.name}-database"
  description = "PostgreSQL ingress from ECS tasks only"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-database" })
}

resource "aws_vpc_security_group_ingress_rule" "database" {
  security_group_id            = aws_security_group.database.id
  description                  = "PostgreSQL from ECS tasks"
  referenced_security_group_id = aws_security_group.application.id
  from_port                    = var.database_port
  to_port                      = var.database_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "application_database" {
  security_group_id            = aws_security_group.application.id
  description                  = "PostgreSQL to the database"
  referenced_security_group_id = aws_security_group.database.id
  from_port                    = var.database_port
  to_port                      = var.database_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "application_dns_udp" {
  security_group_id = aws_security_group.application.id
  description       = "DNS over UDP within the VPC"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_egress_rule" "application_dns_tcp" {
  security_group_id = aws_security_group.application.id
  description       = "DNS over TCP within the VPC"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
}