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
