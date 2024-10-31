resource "aws_ecs_cluster" "ecs_cluster" {
  name = local.app
}

# ecs.tfのaws_cloudwatch_log_groupリソースをリネーム
resource "aws_cloudwatch_log_group" "cloudwatch_log_group_ecs" {
  name              = "/ecs/${local.app}"
  retention_in_days = 7
}


resource "aws_ecs_task_definition" "ecs_task_definition" {
  family             = local.app
  execution_role_arn = aws_iam_role.ecs.arn
  task_role_arn      = aws_iam_role.ecs_task.arn
  network_mode       = "bridge"

  container_definitions = <<CONTAINERS
[
  {
    "name": "${local.app}",
    "image": "medpeer/health_check:latest",
    "portMappings": [
      {
        "hostPort": 8080,
        "containerPort": 8080
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.cloudwatch_log_group.name}",
        "awslogs-region": "${local.region}",
        "awslogs-stream-prefix": "app"
      }
    },
    "environment": [
      {
        "name": "NGINX_PORT",
        "value": "8080"
      },
      {
        "name": "HEALTH_CHECK_PATH",
        "value": "/health_checks"
      }
    ]
  }
]
CONTAINERS
}

resource "aws_ecs_service" "ecs_service" {
  name            = local.app
  launch_type     = "EC2"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task_definition.arn
  desired_count   = 2
  
  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = local.app
    container_port   = 8080
  }

  depends_on = [aws_lb_listener_rule.alb_listener_rule]
}

resource "aws_instance" "ecs_instance" {
  ami                    = "<ECS-optimized AMI ID>"  # リージョンに応じた ECS 最適化 AMI を使用
  instance_type          = "t2.micro"
  iam_instance_profile   = aws_iam_instance_profile.ecs_instance_profile.name
  user_data              = <<-EOF
                            #!/bin/bash
                            echo ECS_CLUSTER=${aws_ecs_cluster.ecs_cluster.name} >> /etc/ecs/ecs.config
EOF
  vpc_security_group_ids = [aws_security_group.ecs_sg.id]
  subnet_id              = module.vpc.public_subnets[0]

  tags = {
    Name = "ecs-instance"
  }
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs_instance_profile"
  role = aws_iam_role.ecs_instance_role.name
}

resource "aws_iam_role" "ecs_instance_role" {
  name = "ecs_instance_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_policy_attach" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}
