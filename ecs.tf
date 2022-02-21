resource "aws_ecs_cluster" "wp_cluster" {
  name = "wordpress-${random_string.install.id}"
}

resource "aws_ecs_cluster_capacity_providers" "wp_cluster" {
  cluster_name = aws_ecs_cluster.wp_cluster.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  default_capacity_provider_strategy {
    base              = 1
    weight            = 0
    capacity_provider = "FARGATE"
  }
  default_capacity_provider_strategy {
    base              = 0
    weight            = 100
    capacity_provider = "FARGATE_SPOT"
  }
}

resource "aws_ecs_service" "wp_service" {
  name = "wordpress-${random_string.install.id}"
  cluster = aws_ecs_cluster.wp_cluster.id
  iam_role = aws_iam_role.ecs_role.arn
  task_definition = aws_ecs_task_definition.wp_task.arn
  force_new_deployment = true
  launch_type = "FARGATE"
  desired_count = 1
  lifecycle {
    ignore_changes = [desired_count]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_target.arn
    container_name = aws_ecs_task_definition.wp_task.family
    container_port = 80
  }
}

resource "aws_ecs_task_definition" "wp_task" {
  family = "wordpress-${random_string.install.id}-task"
  requires_compatibilities = ["FARGATE"]
  cpu = var.ecs_cpu
  memory = var.ecs_mem
  network_mode = "awsvpc"
  
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture = "ARM64"
  }

  volume {
    name = "wp-install"
    host_path = "/var/www/html"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.wp_storage.id
      
    }
  }

  container_definitions = jsonencode([{
    name = "wordpress-${random_string.install.id}-task"
    image = "wordpress:latest"
    essential = true
    portMappings = [{
      containerPort = 80
      hostPort = 80
    }]
  }])
}

resource "aws_appautoscaling_policy" "ecs_policy" {
  name = "wordpress-${random_string.install.id}-task"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_upper_bound = -20
      scaling_adjustment          = -1
    }

    step_adjustment {
      metric_interval_lower_bound = 0
      metric_interval_upper_bound = 15
      scaling_adjustment          = 1
    }
  }
}

resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = var.max_capacity
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.wp_cluster.name}/${aws_ecs_service.wp_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}
