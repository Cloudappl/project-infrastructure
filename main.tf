terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  access_key = "mock_access_key"
  secret_key = "mock_secret_key"
  region     = "us-east-1"
  s3_force_path_style = true
  skip_credentials_validation = true
  skip_metadata_api_check = true
  skip_requesting_account_id = true
  endpoint   = "http://localhost:4566"
}

variable "app_name" {
  default = "my-flask-app"
}


resource "aws_vpc" "localstack_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "localstack_subnet" {
  vpc_id     = aws_vpc.localstack_vpc.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_security_group" "localstack_sg" {
  name_prefix = "${var.app_name}-sg"
  vpc_id      = aws_vpc.localstack_vpc.id

  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_task_definition" "localstack_app_task" {
  family                   = "${var.app_name}-task"
  container_definitions    = jsonencode([
    {
      name      = "${var.app_name}-container"
      image     = "my-flask-app-image"
      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
        },
      ],
      essential = true
    }
  ])
}

resource "aws_ecs_service" "localstack_app_service" {
  name            = "${var.app_name}-service"
  cluster         = "${var.app_name}-cluster"
  task_definition = aws_ecs_task_definition.localstack_app_task.arn
  desired_count   = 1

  network_configuration {
    subnets          = [aws_subnet.localstack_subnet.id]
    security_groups  = [aws_security_group.localstack_sg.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.localstack_app_target_group.arn
    container_name   = "${var.app_name}-container"
    container_port   = 5000
  }
}

resource "aws_lb_target_group" "localstack_app_target_group" {
  name_prefix        = "${var.app_name}-tg"
  port               = 5000
  protocol           = "HTTP"
  vpc_id             = aws_vpc.localstack_vpc.id
  target_type        = "ip"
