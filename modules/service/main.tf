data "aws_iam_policy_document" "task_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.database_secret_arn]
  }

  statement {
    actions   = ["kms:Decrypt"]
    resources = [var.database_kms_key_arn]
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  name   = "read-database-credentials"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_secrets.json
}

resource "aws_iam_role" "task" {
  name               = "${var.name}-task"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "task" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [var.application_bucket_arn]
  }

  statement {
    actions = [
      "s3:AbortMultipartUpload",
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = ["${var.application_bucket_arn}/*"]
  }

  statement {
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
    ]
    resources = [var.application_kms_key_arn]
  }
}

resource "aws_iam_role_policy" "task" {
  name   = "application-bucket"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task.json
}

resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/ecs/${var.name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_kms_key_arn
  tags              = var.tags
}

resource "aws_ecs_cluster" "this" {
  name = var.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.task_cpu)
  memory                   = tostring(var.task_memory)
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn
  container_definitions    = var.container_definitions

  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  tags = var.tags

  depends_on = [aws_cloudwatch_log_group.application]
}

# Public exposure is intentional for this web service; WAF and HTTPS are enforced.
#trivy:ignore:AVD-AWS-0053
resource "aws_lb" "this" {
  name                       = substr(var.name, 0, 32)
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [var.load_balancer_security_group_id]
  subnets                    = var.public_subnet_ids
  enable_deletion_protection = var.deletion_protection
  drop_invalid_header_fields = true
  desync_mitigation_mode     = "strictest"

  access_logs {
    bucket  = var.log_bucket_name
    prefix  = "alb"
    enabled = true
  }

  tags = var.tags
}

resource "aws_lb_target_group" "this" {
  name        = substr(var.name, 0, 32)
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = var.health_check_path
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = var.tags
}

resource "aws_acm_certificate" "this" {
  domain_name       = var.domain_name
  validation_method = "DNS"
  tags              = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validation" {
  for_each = {
    for option in aws_acm_certificate.this.domain_validation_options : option.domain_name => {
      name   = option.resource_record_name
      record = option.resource_record_value
      type   = option.resource_record_type
    }
  }

  zone_id = var.hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.this.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_route53_record" "service" {
  count = var.activate_dns ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}

resource "aws_wafv2_web_acl" "this" {
  name  = var.name
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-common"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimit"
    priority = 30

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.name
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

resource "aws_wafv2_web_acl_association" "this" {
  resource_arn = aws_lb.this.arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}

resource "aws_ecs_service" "this" {
  name                              = var.name
  cluster                           = aws_ecs_cluster.this.id
  task_definition                   = aws_ecs_task_definition.this.arn
  desired_count                     = var.desired_count
  launch_type                       = "FARGATE"
  platform_version                  = "LATEST"
  health_check_grace_period_seconds = 60
  enable_ecs_managed_tags           = true
  propagate_tags                    = "SERVICE"
  wait_for_steady_state             = true

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.application_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.https]

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = var.tags
}

resource "aws_appautoscaling_target" "service" {
  max_capacity       = var.maximum_count
  min_capacity       = var.minimum_count
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.name}-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service.resource_id
  scalable_dimension = aws_appautoscaling_target.service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = 60
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "memory" {
  name               = "${var.name}-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service.resource_id
  scalable_dimension = aws_appautoscaling_target.service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = 70
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  alarm_name          = "${var.name}-unhealthy-targets"
  alarm_description   = "One or more web service targets are unhealthy."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "breaching"
  alarm_actions       = var.alarm_actions

  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
    TargetGroup  = aws_lb_target_group.this.arn_suffix
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "server_errors" {
  alarm_name          = "${var.name}-http-5xx"
  alarm_description   = "The load balancer is returning server errors."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions

  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
    TargetGroup  = aws_lb_target_group.this.arn_suffix
  }

  tags = var.tags
}