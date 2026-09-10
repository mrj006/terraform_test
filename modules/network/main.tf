data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  availability_zones = slice(data.aws_availability_zones.available.names, 0, var.availability_zone_count)
  nat_gateway_azs    = var.single_nat_gateway ? [local.availability_zones[0]] : local.availability_zones
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-igw" })
}

resource "aws_subnet" "public" {
  for_each = toset(local.availability_zones)

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, index(local.availability_zones, each.value))
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name}-public-${each.value}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  for_each = toset(local.availability_zones)

  vpc_id            = aws_vpc.this.id
  availability_zone = each.value
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, 4 + index(local.availability_zones, each.value))

  tags = merge(var.tags, {
    Name = "${var.name}-private-${each.value}"
    Tier = "application"
  })
}

resource "aws_subnet" "database" {
  for_each = toset(local.availability_zones)

  vpc_id            = aws_vpc.this.id
  availability_zone = each.value
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, 8 + index(local.availability_zones, each.value))

  tags = merge(var.tags, {
    Name = "${var.name}-database-${each.value}"
    Tier = "database"
  })
}

resource "aws_eip" "nat" {
  for_each = toset(local.nat_gateway_azs)

  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-nat-${each.value}" })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  for_each = toset(local.nat_gateway_azs)

  allocation_id = aws_eip.nat[each.value].id
  subnet_id     = aws_subnet.public[each.value].id
  tags          = merge(var.tags, { Name = "${var.name}-nat-${each.value}" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-public" })
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-private-${each.key}" })
}

resource "aws_route" "private_egress" {
  for_each = aws_route_table.private

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.single_nat_gateway ? local.availability_zones[0] : each.key].id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_route_table" "database" {
  for_each = aws_subnet.database

  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-database-${each.key}" })
}

resource "aws_route_table_association" "database" {
  for_each = aws_subnet.database

  subnet_id      = each.value.id
  route_table_id = aws_route_table.database[each.key].id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for route_table in aws_route_table.private : route_table.id]
  tags              = merge(var.tags, { Name = "${var.name}-s3" })
}

data "aws_region" "current" {}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/${var.name}/flow-logs"
  retention_in_days = var.flow_log_retention_days
  kms_key_id        = var.log_kms_key_arn
  tags              = var.tags
}

data "aws_iam_policy_document" "flow_logs_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow_logs" {
  name               = "${var.name}-vpc-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "flow_logs" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.flow_logs.arn}:*"]
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  name   = "flow-logs"
  role   = aws_iam_role.flow_logs.id
  policy = data.aws_iam_policy_document.flow_logs.json
}

resource "aws_flow_log" "this" {
  iam_role_arn             = aws_iam_role.flow_logs.arn
  log_destination          = aws_cloudwatch_log_group.flow_logs.arn
  log_destination_type     = "cloud-watch-logs"
  traffic_type             = "ALL"
  vpc_id                   = aws_vpc.this.id
  max_aggregation_interval = 60

  tags = var.tags
}