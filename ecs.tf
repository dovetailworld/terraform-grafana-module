# Create the ECS cluster
resource "aws_ecs_cluster" "this" {
  name = var.service_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Create CloudWatch log group
resource "aws_cloudwatch_log_group" "this" {
  name              = var.cloudwatch_log_group_name
  retention_in_days = 30
}

# Create the task definition by passing it the container definition
locals {
  container_definitions = templatefile("${path.module}/container-definition/container-definition.json", {
    aws_region                = var.aws_region
    container_name            = var.service_name
    service_name              = var.service_name
    image                     = var.image
    version                   = var.image_version
    cloudwatch_log_group_name = aws_cloudwatch_log_group.this.name
    cpu                       = var.cpu
    memory                    = var.memory
    container_port            = var.container_port
  })
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.service_name
  container_definitions    = local.container_definitions
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  requires_compatibilities = ["FARGATE"]
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  volume {
    name = "grafana-db"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.this.id
      root_directory     = "/"
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.this.id
        iam             = "DISABLED"
      }
    }
  }
}

# Create the ECS service
resource "aws_ecs_service" "this" {
  name                               = var.service_name
  cluster                            = var.ecs_cluster
  task_definition                    = aws_ecs_task_definition.this.arn
  desired_count                      = var.desired_number_of_tasks
  deployment_maximum_percent         = var.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds
  launch_type                        = "FARGATE"
  platform_version                   = var.platform_version
  depends_on                         = [aws_lb_target_group.this]

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_service_security_group.id]
    assign_public_ip = var.assign_public_ip
  }
}
