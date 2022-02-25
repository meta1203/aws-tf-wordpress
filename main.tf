provider "aws" {
  region = var.region
}

resource "random_string" "install" {
  length = 8
  lower = true
  upper = false
  number = true
  special = false
}

resource "random_string" "pw" {
  length = 16
  lower = true
  upper = true
  number = true
  special = true
}

resource "aws_iam_role" "ecs_task_role" {
  name = "wordpress-${random_string.install.id}-ecstasksrole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
	Action = "sts:AssumeRole"
	Effect = "Allow"
	Sid    = ""
	Principal = {
	  Service = "ecs-tasks.amazonaws.com"
	}
      },
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"] # AWS managed ECS policy
}

resource "aws_iam_role_policy" "ecs_task_policy" {
  name = "wordpress-${random_string.install.id}-ecspolicy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
	  "elasticfilesystem:ClientMount",
	  "elasticfilesystem:ClientWrite"
        ]
        Effect   = "Allow"
        Resource = aws_efs_file_system.wp_storage.arn
      },
      {
        Action = [
	  "logs:PutLogEvents",
        ]
        Effect   = "Allow"
        Resource = aws_cloudwatch_log_group.wp_log.arn
      },
    ]
  })
}

data "aws_availability_zones" "available" {
  state = "available"
}

terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
    }

    aws = {
      source  = "hashicorp/aws"
    }
  }

  required_version = ">= 0.14"
}
