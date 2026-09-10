locals {
  container_name = "application"
  container_definitions = jsonencode([
    {
      name      = local.container_name
      image     = var.container_image
      essential = true
      portMappings = [{
        name          = "http"
        containerPort = var.container_port
        hostPort      = var.container_port
        protocol      = "tcp"
      }]
      environment = [
        { name = "APP_ENV", value = var.environment },
        { name = "AWS_REGION", value = data.aws_region.current.region },
        { name = "DB_HOST", value = module.database.endpoint },
        { name = "DB_READER_HOST", value = module.database.reader_endpoint },
        { name = "DB_NAME", value = module.database.database_name },
        { name = "DB_PORT", value = "5432" },
        { name = "S3_BUCKET", value = module.storage.application_bucket_name },
      ]
      secrets = [
        { name = "DB_USERNAME", valueFrom = "${module.database.master_secret_arn}:username::" },
        { name = "DB_PASSWORD", valueFrom = "${module.database.master_secret_arn}:password::" },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/aws/ecs/${var.name}"
          awslogs-region        = data.aws_region.current.region
          awslogs-stream-prefix = "application"
        }
      }
      readonlyRootFilesystem = true
      linuxParameters = {
        initProcessEnabled = true
      }
    }
  ])
}