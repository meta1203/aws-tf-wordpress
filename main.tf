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


resource "aws_iam_role" "ecs_role" {
  name = "wordpress-${random_string.install.id}-ecsrole"
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

# manually state versions due to permissions issues with the 4.x branch
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
    }

    aws = {
      source  = "hashicorp/aws"
      # version = "= 3.72.0"
    }
  }

  required_version = ">= 0.14"
}
