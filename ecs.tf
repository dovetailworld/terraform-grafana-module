# Define the assume role IAM policy document for the ECS service scheduler IAM role
data "aws_iam_policy_document" "this" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Create the IAM roles for the ECS task
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.service_name}-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.this.json
}

resource "aws_iam_role" "ecs_task_role" {
  name               = "${var.service_name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.this.json
}

# Configure additional IAM policies for the ECS service and task
resource "aws_iam_policy" "ecs_task_custom_policy" {
  name = "${var.service_name}-ecs-task-custom-policy"
  path = "/"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowReadingTagsInstancesRegionsFromEC2",
      "Effect": "Allow",
      "Action": ["ec2:DescribeTags", "ec2:DescribeInstances", "ec2:DescribeRegions"],
      "Resource": "*"
    },
    {
      "Sid": "AllowReadingResourcesForTags",
      "Effect": "Allow",
      "Action": "tag:GetResources",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "task_custom" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_custom_policy.arn
}

resource "aws_iam_role_policy_attachment" "task_ecr" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_role_policy_attachment" "task_cloudwatch" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

resource "aws_iam_role_policy_attachment" "task_ssm_ro" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "task_execution_custom" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_task_custom_policy.arn
}

resource "aws_iam_role_policy_attachment" "task_execution_ecr" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_role_policy_attachment" "task_execution_cloudwatch" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

resource "aws_iam_role_policy_attachment" "task_execution_ssm_ro" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

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
    root_url                  = var.root_url
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

# Create the ECS service(s)
resource "aws_ecs_service" "fargate_ondemand" {
  # Create this resource when 'var.enable_spot' & 'var.enable_fallback' are both true.
  count = (var.enable_spot && !var.enable_fallback) ? 0 : 1

  name                               = "${var.service_name}-ondemand"
  cluster                            = aws_ecs_cluster.this.arn
  task_definition                    = aws_ecs_task_definition.this.arn
  desired_count                      = 0
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
    security_groups  = [aws_security_group.ecs_service_sg.id]
    assign_public_ip = var.assign_public_ip
  }

  lifecycle {
    replace_triggered_by = [aws_security_group.ecs_service_sg.id]
  }
}

resource "aws_ecs_service" "fargate_spot" {
  # Create this resource when either 'var.enable_spot' or 'var.enable_fallback' is true.
  count = (var.enable_spot || var.enable_fallback) ? 1 : 0

  name                               = "${var.service_name}-spot"
  cluster                            = aws_ecs_cluster.this.arn
  task_definition                    = aws_ecs_task_definition.this.arn
  desired_count                      = var.desired_number_of_tasks
  deployment_maximum_percent         = var.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
    base              = 1
  }

  platform_version = var.platform_version
  depends_on       = [aws_lb_target_group.this]

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_service_sg.id]
    assign_public_ip = var.assign_public_ip
  }

  lifecycle {
    replace_triggered_by = [aws_security_group.ecs_service_sg.id]
  }
}
