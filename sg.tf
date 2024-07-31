# Security group for the EFS share and mount target
resource "aws_security_group" "efs_sg" {
  name        = "${var.service_name}-efs-sg"
  description = "Allow traffic to EFS from the ${var.service_name} service."
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "TCP"
    description     = "${var.service_name} service"
    security_groups = [aws_security_group.ecs_service_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    name = "${var.service_name}-efs-sg"
  }
}

# Security group for the Grafana ECS service
resource "aws_security_group" "ecs_service_sg" {
  name        = "${var.service_name}-service-sg"
  description = "Allow traffic to the ${var.service_name} service."
  vpc_id      = var.vpc_id

  ingress {
    from_port       = var.grafana_container_port
    to_port         = var.grafana_container_port
    protocol        = "TCP"
    description     = "Custom HTTP ALB"
    security_groups = [aws_security_group.alb_sg.id]

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    name = "${var.service_name}-service-sg"
  }
}

# Security group for the ALB
resource "aws_security_group" "alb_sg" {
  name        = "${var.service_name}-alb-sg"
  description = "Allow HTTP(S) traffic to the ALB for the ${var.service_name} service."
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    description = "HTTP"
    cidr_blocks = var.allow_inbound_from_cidr_blocks
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    description = "HTTPS"
    cidr_blocks = var.allow_inbound_from_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    name = "${var.service_name}-alb-sg"
  }
}
