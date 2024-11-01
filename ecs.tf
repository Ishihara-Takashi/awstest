resource "aws_ecs_task_definition" "ecs_task_definition" {
  family                = local.app
  execution_role_arn    = aws_iam_role.ecs.arn
  task_role_arn         = aws_iam_role.ecs_task.arn
  network_mode          = "awsvpc" # ネットワークモードを awsvpc に変更
  cpu                   = 256
  memory                = 512
  container_definitions = <<CONTAINERS
[
  {
    "name": "${local.app}",
    "image": "medpeer/health_check:latest",
    "portMappings": [
      {
        "containerPort": 8080,
        "hostPort": 8080
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


resource "aws_ecs_cluster" "ecs_cluster" {
  name = local.app
}

resource "aws_instance" "ecs_instance" {
  ami                         = data.aws_ssm_parameter.ecs_optimized_ami.value # EC2用のECS最適化AMI
  instance_type               = "t2.micro"
  iam_instance_profile        = aws_iam_instance_profile.ecs_instance_profile.name
  associate_public_ip_address = true # パブリックIPを自動割り当て
  user_data                   = <<-EOF
                            #!/bin/bash
                            echo ECS_CLUSTER=${aws_ecs_cluster.ecs_cluster.name} >> /etc/ecs/ecs.config
                          EOF
  vpc_security_group_ids      = [aws_security_group.ecs_sg.id]
  subnet_id                   = module.vpc.public_subnets[0]

  tags = {
    Name = "ecs-instance"
  }
}

data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

# IAM Role and Instance Profile for ECS EC2 instance
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

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs_instance_profile"
  role = aws_iam_role.ecs_instance_role.name
}

resource "aws_iam_role_policy_attachment" "ecs_instance_policy_attach" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# Security Group for ECS EC2 instance
resource "aws_security_group" "ecs_sg" {
  name        = "${local.app}-ecs-sg"
  description = "ECS security group for ${local.app}"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
