################################################################################
# ECS
################################################################################

locals {
  ecs_service_launch_type = "FARGATE"

  volume_name           = "${var.name}-volume"
  awslogs_group         = var.logs_cloudwatch_group == "" ? "/ecs/${var.name}/${var.name}" : var.logs_cloudwatch_group
  target_container_name = var.target_container_name == "" ? "${var.name}" : var.target_container_name
  cloudwatch_alarm_name = var.cloudwatch_alarm_name == "" ? "${var.name}" : var.cloudwatch_alarm_name

  lb_target_groups = [
    {
      container_port              = var.container_port
      container_health_check_port = var.container_port
    }
  ]

  # For each target group, allow ingress from the alb to ecs container port.
  lb_ingress_container_ports = distinct(
    [
      for lb_target_group in local.lb_target_groups : lb_target_group.container_port
    ]
  )

  # For each target group, allow ingress from the alb to ecs healthcheck port.
  # If it doesn't collide with the container ports.
  lb_ingress_container_health_check_ports = tolist(
    setsubtract(
      [
        for lb_target_group in local.lb_target_groups : lb_target_group.container_health_check_port
      ],
      local.lb_ingress_container_ports,
    )
  )

  ecs_service_agg_security_groups = compact(concat(tolist([var.ecs_sg_id]), var.additional_security_group_ids))
}

################################################################################
# KMS
################################################################################

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "cloudwatch_logs_allow_kms" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
      ]
    }

    actions = [
      "kms:*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "Allow logs KMS access"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logs.${var.aws_region}.amazonaws.com"]
    }

    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = ["*"]
  }
}

resource "aws_kms_key" "main" {
  description         = "Key for ECS log encryption"
  enable_key_rotation = true

  policy = data.aws_iam_policy_document.cloudwatch_logs_allow_kms.json
}



################################################################################
# Alarms
################################################################################

module "aws-alb-alarms" {
  source           = "../alarms"
  load_balancer_id = aws_lb.main[0].id
  target_group_id  = aws_lb_target_group.https[0].id
}

################################################################################
# Application Load Balancer
################################################################################

resource "aws_lb" "main" {
  count              = var.associate_alb ? 1 : 0
  name               = substr(var.name, 0, 32) # The name builder is too long.
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg[0].id]
  subnets            = var.ecs_public_subnets
}

resource "aws_lb_listener" "redirect" {
  count             = var.enable_https && var.associate_alb ? 1 : 0
  load_balancer_arn = aws_lb.main[0].id

  port     = 80
  protocol = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  count = var.enable_https && var.associate_alb ? 1 : 0

  load_balancer_arn = aws_lb.main[0].id
  certificate_arn   = var.certificate_arn

  port       = 443
  protocol   = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-FS-1-2-Res-2020-10"

  default_action {
    target_group_arn = aws_lb_target_group.https[0].id
    type             = "forward"
  }
}

resource "aws_lb_target_group" "https" {
  count = var.associate_alb ? 1 : 0

  name     = substr(var.name, 0, 32)
  port     = var.container_port
  protocol = "HTTPS"

  vpc_id      = var.ecs_vpc_id
  target_type = "ip"

  deregistration_delay = 90

  health_check {
    timeout             = 15
    interval            = 60
    path                = var.health_check_url
    protocol            = "HTTPS"
    healthy_threshold   = 3
    unhealthy_threshold = 10
    matcher             = "200,302"
  }
}

################################################################################
# Application Load Balancer - Security Groups
################################################################################

resource "aws_security_group" "lb_sg" {
  count = var.associate_alb ? 1 : 0

  name   = "lb-${var.name}"
  vpc_id = var.ecs_vpc_id
}

resource "aws_security_group_rule" "app_lb_allow_outbound" {
  count = var.associate_alb ? 1 : 0

  security_group_id = aws_security_group.lb_sg[0].id

  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "app_lb_allow_all_http" {
  count = var.associate_alb ? 1 : 0

  security_group_id = aws_security_group.lb_sg[0].id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "app_lb_allow_all_https" {
  count = var.associate_alb ? 1 : 0

  security_group_id = aws_security_group.lb_sg[0].id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

################################################################################
# Cloudwatch
################################################################################

resource "aws_cloudwatch_log_group" "main" {
  name              = local.awslogs_group
  retention_in_days = var.logs_cloudwatch_retention

  kms_key_id = aws_kms_key.main.arn
}

resource "aws_cloudwatch_metric_alarm" "alarm_cpu" {
  count = var.cloudwatch_alarm_cpu_enable ? 1 : 0

  alarm_name        = "${local.cloudwatch_alarm_name}-cpu"
  alarm_description = "Monitors ECS CPU Utilization"
  alarm_actions     = var.cloudwatch_alarm_actions

  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "120"
  statistic           = "Average"
  threshold           = var.cloudwatch_alarm_cpu_threshold

  dimensions = {
    "ClusterName" = var.aws_ecs_cluster.name
    "ServiceName" = aws_ecs_service.main.name
  }
}

resource "aws_cloudwatch_metric_alarm" "alarm_mem" {
  count = var.cloudwatch_alarm_mem_enable ? 1 : 0

  alarm_name        = "${local.cloudwatch_alarm_name}-mem"
  alarm_description = "Monitors ECS memory Utilization"
  alarm_actions     = var.cloudwatch_alarm_actions

  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "120"
  statistic           = "Average"
  threshold           = var.cloudwatch_alarm_mem_threshold

  dimensions = {
    "ClusterName" = var.aws_ecs_cluster.name
    "ServiceName" = aws_ecs_service.main.name
  }
}

################################################################################
# Security
################################################################################

resource "aws_security_group_rule" "app_ecs_allow_outbound" {
  description       = "All outbound"
  security_group_id = var.ecs_sg_id

  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "app_ecs_allow_https_from_alb" {
  count = var.associate_alb ? length(local.lb_ingress_container_ports) : 0

  description       = "Allow in ALB"
  security_group_id = var.ecs_sg_id

  type                     = "ingress"
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lb_sg[0].id
}

################################################################################
# IAM - Policy
################################################################################

data "aws_iam_policy_document" "ecs_assume_role_policy" {

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

################################################################################
# IAM - Task Roles / Policies (used by the task manager)
################################################################################

data "aws_iam_policy_document" "task_execution_role_policy_doc" {

  # Docker hub authentication
  statement {
    actions = [
      "secretsmanager:GetSecretValue"
    ]

    resources = ["${var.ssm_docker}"]
  }


  # awslogger
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.main.arn}:*"]
  }
}

resource "aws_iam_role" "task_role" {
  name               = "ecs-task-role-${var.name}"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json
}

################################################################################
# IAM - Task Execution Role / Policies (used by the task itself)
################################################################################

resource "aws_iam_role" "task_execution_role" {
  name               = "ecs-task-execution-role-${var.name}"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json
}

resource "aws_iam_role_policy" "task_execution_role_policy" {
  name   = "${aws_iam_role.task_execution_role.name}-policy"
  role   = aws_iam_role.task_execution_role.name
  policy = data.aws_iam_policy_document.task_execution_role_policy_doc.json
}

data "aws_iam_policy_document" "task_role_ecs_exec" {

  # S3 Access for manifest files (optional).
  statement {
    sid = "AllowBucketAccess"

    actions = [
      "s3:*",
    ]

    resources = var.s3_resources
  }

  # ECS exec for debugging
  statement {
    sid = "AllowECSExec"

    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    resources = ["*"]
  }

  statement {
    sid = "AllowDescribeLogGroups"

    actions = [
      "logs:DescribeLogGroups",
    ]
    resources = ["*"]
  }

  statement {
    sid = "AllowECSExecLogging"

    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.main.arn}:*"]
  }
}

resource "aws_iam_policy" "task_role_ecs_exec" {
  name        = "${aws_iam_role.task_role.name}-ecs-exec"
  description = "Allow ECS Exec with Cloudwatch logging when attached to an ECS task role"
  policy      = join("", data.aws_iam_policy_document.task_role_ecs_exec.*.json)
}

resource "aws_iam_role_policy_attachment" "task_role_ecs_exec" {
  role       = join("", aws_iam_role.task_role.*.name)
  policy_arn = join("", aws_iam_policy.task_role_ecs_exec.*.arn)
}

################################################################################
# ECS - Service
################################################################################

resource "aws_ecs_service" "main" {
  name    = var.name
  cluster = var.aws_ecs_cluster.arn

  launch_type            = local.ecs_service_launch_type
  enable_execute_command = var.ecs_exec_enable

  # Use latest active revision
  task_definition = "${aws_ecs_task_definition.main.family}:${max(
    aws_ecs_task_definition.main.revision,
    data.aws_ecs_task_definition.main.revision,
  )}"

  desired_count                      = var.tasks_desired_count
  deployment_minimum_healthy_percent = var.tasks_minimum_healthy_percent
  deployment_maximum_percent         = var.tasks_maximum_percent

  # If you cannot connect outbound to the internet from a task, make sure that the EC2 machine, service, and task are being run in the private subnet.
  # Counterintuitive, but the tasks must be routed outwards through the NAT gateway.
  network_configuration {
    subnets          = var.ecs_private_subnets
    security_groups  = local.ecs_service_agg_security_groups
    assign_public_ip = var.assign_public_ip
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.https[0].arn
    container_name   = local.target_container_name
    container_port   = var.container_port
  }

  health_check_grace_period_seconds = var.health_check_grace_period_seconds
}

################################################################################
# Task Definition (ECS)
################################################################################

resource "random_uuid" "keycloak_secret" {}
resource "random_uuid" "api_secret" {}

resource "tls_private_key" "jwt" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_ecs_task_definition" "main" {
  family             = var.name
  network_mode       = "awsvpc"
  task_role_arn      = aws_iam_role.task_role.arn
  execution_role_arn = aws_iam_role.task_execution_role.arn

  requires_compatibilities = ["FARGATE"]

  cpu    = 2048
  memory = 8192

  container_definitions = jsonencode(
    [for s in var.services :
      merge(
        ({
          for k, v in s :
          k => v
          if v != null
        }),
        {
          name  = s.name
          image = s.image ? s.image_id : "secoda/on-premise-${s.name}:${s.tag}"

          "repositoryCredentials" = {
            "credentialsParameter" : "${var.ssm_docker}"
          }

          cpu               = tonumber(s.cpu),
          memoryReservation = tonumber(s.mem)
          essential         = tobool(s.essential)

          requires_compatibilities = ["FARGATE"]

          portMappings = [for p in s.ports :
            {
              containerPort = tonumber(p)
              hostPort      = tonumber(p)
              protocol      = "tcp"
            }
          ]

          environment = flatten([s.environment,
            {
              "name" : "APISERVICE_SECRET",
              "value" : random_uuid.api_secret.result,
            },
            {
              name  = "PRIVATE_KEY"
              value = base64encode(tls_private_key.jwt.private_key_pem)
            },
            {
              name  = "PUBLIC_KEY"
              value = base64encode(tls_private_key.jwt.public_key_pem)
            },
            {
              "name" : "PRIVATE_BUCKET", # This is where all the private files will be stored.
              "value" : var.private_bucket,
            },
            {
              "name" : "REDIS_URL",
              "value" : "rediss://default:${var.redis_auth_token}@${var.redis_addr}:6379",
            },
            {
              "name" : "APISERVICE_DATABASE_CONNECTION",
              "value" : "postgresql://keycloak:${var.keycloak_database_password}@${var.db_addr}:5432/secoda",
            },
            {
              "name" : "ES_CONNECTION_STRING",
              "value" : "https://elastic:${var.es_password}@${var.es_host}:443",
            },
            # Keycloak
            {
              "name" : "KEYCLOAK_ADMIN_PASSWORD", # >= v18
              "value" : var.keycloak_admin_password,
            },
            {
              "name" : "KEYCLOAK_PASSWORD", # Needed for backwards compatibility.
              "value" : var.keycloak_admin_password,
            },
            {
              "name" : "KEYCLOAK_SECRET",
              "value" : var.keycloak_secret_key == null ? random_uuid.keycloak_secret.result : var.keycloak_secret_key,
            },
            {
              "name" : "KC_DB_PASSWORD", # >= v18
              "value" : var.keycloak_database_password,
            },
            {
              "name" : "KC_DB_URL", # >= v18
              "value" : "jdbc:postgresql://${var.db_addr}/keycloak",
            },

          ])

          command = s.command

          dependsOn = s.dependsOn

          healthCheck = s.healthCheck

          mountPoints = s.mountPoints

          ulimits = s.ulimits

          logConfiguration = {
            logDriver = "awslogs"
            options = {
              "awslogs-group"         = local.awslogs_group
              "awslogs-region"        = var.aws_region
              "awslogs-stream-prefix" = "${s.name}-logs"
            }
          }
      })
    ]
  )

  lifecycle {
    ignore_changes = [
      requires_compatibilities,
      cpu,
      memory,
      execution_role_arn,
    ]
  }
}

# Create a data source to pull the latest active revision from.
data "aws_ecs_task_definition" "main" {
  task_definition = aws_ecs_task_definition.main.family
  depends_on      = [aws_ecs_task_definition.main] # ensures at least one task def exists
}
