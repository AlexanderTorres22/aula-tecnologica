//////////// permisos ////////////////////

resource "aws_security_group" "lb_fargate" {
  name        = "lb_security_group_aula_tecnologica"
  description = "controls access to the ALB"
  vpc_id      = var.vpc

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name   = "lb_security_group_aula_tecnologica"
    Source = "Terraform"
  }
}

# Traffic to the ECS cluster should only come from the ALB
resource "aws_security_group" "ecs_tasks_fargate" {
  name        = "ecs_task_security_group_aula_tecnologica"
  description = "allow inbound access from the ALB only"
  vpc_id      = var.vpc

  ingress {
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
    security_groups = [aws_security_group.lb_fargate.id]
  }

  ingress {
    protocol        = "tcp"
    from_port       = 443
    to_port         = 443
    security_groups = [aws_security_group.lb_fargate.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name   = "ecs_task_security_group_aula_tecnologica"
    Source = "Terraform"
  }
}

resource "aws_iam_role" "task_role_arn" {
  name               = "aula-task-role-fargate-acces"
  assume_role_policy = data.aws_iam_policy_document.task_role_arn_policy_document.json
}

data "aws_iam_policy_document" "task_role_arn_policy_document" {
  version = "2012-10-17"
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "s3.amazonaws.com",
        "lambda.amazonaws.com",
        "ecs.amazonaws.com",
        "batch.amazonaws.com",
        "ecs-tasks.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role_policy_attachment" "task_role_policy_attachment" {
  role       = aws_iam_role.task_role_arn.name
  policy_arn = aws_iam_policy.task_role_arn_policy.arn
}

resource "aws_iam_policy" "task_role_arn_policy" {
  name = "aula-task-role-policy-fargate-access"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
        "Sid": "Stmt1532966429082",
        "Action": [
        "s3:PutObject",
        "s3:PutObjectTagging",
        "s3:PutObjectVersionTagging"
        ],
        "Effect": "Allow",
        "Resource": "arn:aws:s3:::*"
    },
    {
        "Sid": "Stmt1532967608746",
        "Action": "lambda:*",
        "Effect": "Allow",
        "Resource": "*"
    },
    {
        "Effect": "Allow",
        "Action": [
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
            ],
            "Resource": "*"
        },
    {
        "Sid": "VisualEditor0",
        "Effect": "Allow",
        "Action": [
            "ssm:PutParameter",
            "ssm:DeleteParameter",
            "ssm:GetParameterHistory",
            "ssm:GetParametersByPath",
            "ssm:GetParameters",
            "ssm:GetParameter",
            "ssm:DeleteParameters"
            ],
            "Resource": "arn:aws:ssm:${var.region}:${var.account_id}:parameter/*"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "ssm:DescribeParameters",
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.layer}-ecs-task-role-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_role.json
}

data "aws_iam_policy_document" "ecs_task_execution_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_tasks_execution_role" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.task_execution_policy.arn
}

resource "aws_iam_policy" "task_execution_policy" {
  name   = "${var.layer}-task-policy-fargate-execution"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [    
        {
        "Effect": "Allow",
        "Action": [
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
            ],
            "Resource": "*"
        },
        {
        "Effect": "Allow",
            "Action": [
                "ssm:GetParameters",
                "secretsmanager:GetSecretValue",
                "kms:Decrypt",
                "ssm:GetParametersByPath"
            ],
            "Resource": [
                "arn:aws:ssm:${var.region}:${var.account_id}:parameter/*",
                "arn:aws:kms:${var.region}:${var.account_id}:key/*"
            ]
        }        
    ]
}
EOF
}

/////////////////////////////////////////////////// Configuracion //////

#Create ECR repository
resource "aws_ecr_repository" "ecr" {
  name                 = "container_ecr_aula_tecnologica"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = {
    Name   = "ecr_aula_tecnologica"
    Source = "Terraform"
  }
}

# Create ALB
resource "aws_alb" "main" {
  name            = "alb_aula_tecnologica"
  subnets         = var.db_subnets_public
  security_groups = [aws_security_group.lb_fargate.id]
}

resource "aws_alb_target_group" "aula_tecnologica" {
  name        = "target-group-aula-tecnologica"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc
  target_type = "ip"

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "10"
    path                = "/aula/health"
    unhealthy_threshold = "5"
  }
}


# Redirect all traffic from the ALB to the target group
resource "aws_alb_listener" "listener" {
  load_balancer_arn = aws_alb.main.id
  port              = var.app_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.aula_tecnologica.id
  }
}

# Create ECS cluster
resource "aws_ecs_cluster" "main" {
  name               = "cluster_aula_tecnologica"
  capacity_providers = "FARGATE"
  default_capacity_provider_strategy {
    base              = var.app_count
    weight            = 1
    capacity_provider = "FARGATE"
  }
}

data "template_file" "service" {

  template = file("./modules/fargategestion/templates/ecs/service.json.tpl")

  vars = {
    app_image = "${element(aws_ecr_repository.ecr.*.repository_url, count.index)}:latest"
    #app_image      = var.app_image
    app_port       = var.app_port
    fargate_cpu    = var.fargate_cpu
    fargate_memory = var.fargate_memory
    region         = var.region
    account_id     = var.account_id
    layer          = var.layer
    stack_id       = var.stack_id
    name           = "aula"
    #enviroments
    parameters_secrets = var.parameters_secrets
  }
}

resource "aws_ecs_task_definition" "ecs_task" {
  family                   = "task_aula_tecnologica"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.task_role_arn.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  container_definitions    = element(data.template_file.service.*.rendered, count.index)
}

resource "aws_ecs_service" "main" {
  name            = "service-aula-tecnologica"
  cluster         = aws_ecs_cluster.main.id
  task_definition = element(aws_ecs_task_definition.ecs_task.*.arn, count.index)
  desired_count   = var.app_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks_fargate.id]
    subnets          = var.db_subnets_private
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.aula_tecnologica.id
    container_name   = "container_${var.layer}_${var.stack_id}"
    container_port   = var.app_port
  }

  depends_on = [aws_iam_role_policy_attachment.ecs_task_execution_role]
}