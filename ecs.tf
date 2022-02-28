resource "aws_ecs_cluster" "wp_cluster" {
  name = "wordpress-${random_string.install.id}"

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"
      log_configuration {
	cloud_watch_log_group_name = aws_cloudwatch_log_group.wp_log.name
      }
    }
  }
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
  
  network_configuration {
    subnets = aws_subnet.sn.*.id
    security_groups = [aws_security_group.sg.id]
    assign_public_ip = true
  }
  
  depends_on = [aws_lb.ecs_balancer, aws_lb_target_group.ecs_target, aws_lb_listener.ecs_listener]
}

resource "aws_ecs_task_definition" "wp_task" {
  family = "wordpress-${random_string.install.id}-task"
  requires_compatibilities = ["FARGATE"]
  cpu = var.ecs_cpu
  memory = var.ecs_mem
  network_mode = "awsvpc"
  execution_role_arn = aws_iam_role.ecs_exec_role.arn
  task_role_arn = aws_iam_role.ecs_task_role.arn
  
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture = "ARM64"
  }

  volume {
    name = "wp-install"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.wp_storage.id
      root_directory = "/"
    }
  }

  container_definitions = jsonencode([{
    name = "wordpress-${random_string.install.id}-task"
    image = "wordpress:latest"
    essential = true
    
    environment = [{
      name  = "WORDPRESS_DB_HOST"
      value = aws_rds_cluster.wp_db.endpoint
    }, {
      name  = "WORDPRESS_DB_USER"
      value = aws_rds_cluster.wp_db.master_username
    }, {
      name  = "WORDPRESS_DB_PASSWORD"
      value = aws_rds_cluster.wp_db.master_password
    }, {
      name  = "WORDPRESS_DB_NAME"
      value = aws_rds_cluster.wp_db.database_name
    }, {
      name  = "WORDPRESS_TABLE_PREFIX"
      value = "wp_"
    }]
    
    portMappings = [{
      containerPort = 80
      hostPort = 80
    }]

    mountPoints = [{
      containerPath = "/var/www/html"
      sourceVolume = "wp-install"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
	"awslogs-group" = aws_cloudwatch_log_group.wp_log.name
	"awslogs-region" = var.region
	"awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_cloudwatch_metric_alarm" "wp_alarm_high" {
  alarm_name          = "wp-${random_string.install.id}-Alarm-High"
  alarm_description   = "Upper bound for WordPress ECS scaling policy"
  alarm_actions       = [aws_appautoscaling_policy.ecs_up.arn]
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = 90

  metric_query {
    id = "max"
    expression = "MAX(METRICS())"
    label = "Consumption"
    return_data = true
  }

  metric_query {
    id = "cpu"
    metric {
      metric_name = "CPUUtilization"
      period = 60
      namespace = "AWS/ECS"
      stat = "Maximum"

      dimensions = {
	ClusterName = aws_ecs_cluster.wp_cluster.name
	ServiceName  = aws_ecs_service.wp_service.name
      }
    }
  }

  metric_query {
    id = "mem"
    metric {
      metric_name = "MemoryUtilization"
      period = 60
      namespace = "AWS/ECS"
      stat = "Maximum"

      dimensions = {
	ClusterName = aws_ecs_cluster.wp_cluster.name
	ServiceName  = aws_ecs_service.wp_service.name
      }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "wp_alarm_low" {
  alarm_name          = "wp-${random_string.install.id}-Alarm-Low"
  alarm_description   = "Lower bound for WordPress ECS scaling policy"
  alarm_actions       = [aws_appautoscaling_policy.ecs_down.arn]
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = 50

  metric_query {
    id = "max"
    expression = "MAX(METRICS())"
    label = "Consumption"
    return_data = true
  }

  metric_query {
    id = "cpu"
    metric {
      metric_name = "CPUUtilization"
      period = 60
      namespace = "AWS/ECS"
      stat = "Maximum"

      dimensions = {
	ClusterName = aws_ecs_cluster.wp_cluster.name
	ServiceName  = aws_ecs_service.wp_service.name
      }
    }
  }

  metric_query {
    id = "mem"
    metric {
      metric_name = "MemoryUtilization"
      period = 60
      namespace = "AWS/ECS"
      stat = "Maximum"

      dimensions = {
	ClusterName = aws_ecs_cluster.wp_cluster.name
	ServiceName  = aws_ecs_service.wp_service.name
      }
    }
  }
}

resource "aws_appautoscaling_policy" "ecs_up" {
  name = "wordpress-${random_string.install.id}-up"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }
}

resource "aws_appautoscaling_policy" "ecs_down" {
  name = "wordpress-${random_string.install.id}-down"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
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
