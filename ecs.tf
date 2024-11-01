resource "aws_ecs_task_definition" "ecs_task_definition" {
  family                = local.app
  execution_role_arn    = aws_iam_role.ecs.arn
  task_role_arn         = aws_iam_role.ecs_task.arn
  network_mode          = "bridge" # EC2インスタンスでの実行のため
  cpu                   = 256
  memory                = 512
  container_definitions = <<CONTAINERS
[{
    "name": "${local.app}",
    "image": "medpeer/health_check:latest",
    "portMappings": [{"containerPort": 8080, "hostPort": 8080}],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.cloudwatch_log_group.name}",
        "awslogs-region": "${local.region}",
        "awslogs-stream-prefix": "app"
      }
    },
    "environment": [
      {"name": "NGINX_PORT", "value": "8080"},
      {"name": "HEALTH_CHECK_PATH", "value": "/health_checks"}
    ]
}]
CONTAINERS
}

resource "aws_ecs_service" "ecs_service" {
  name            = local.app
  launch_type     = "EC2"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task_definition.arn
  desired_count   = 2
  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.ecs_sg.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = local.app
    container_port   = 8080
  }
  depends_on = [aws_lb_listener_rule.alb_listener_rule]
}
