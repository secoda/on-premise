################################################################################
# Environment Vars
################################################################################

variable "redis_addr" {
  type = string
}

variable "redis_auth_token" {
  type = string
}

variable "db_addr" {
  type = string
}

variable "es_host" {
  type = string
}

variable "es_password" {
  type = string
}

variable "keycloak_admin_password" {
  type        = string
  description = "The password for the keycloak `admin`."
}

variable "keycloak_database_password" {
  type        = string
  description = "The password for the database."
}

################################################################################
# S3
################################################################################

variable "s3_resources" { // The private bucket resources.
  type = list(string)
}

variable "private_bucket" { // The private bucket name where application files will be stored.
  type = string
}

################################################################################
# Docker Hub Authentication
################################################################################

variable "ssm_docker" {
  type = string
}

################################################################################
# ECS
################################################################################

variable "name" {
  description = "The service name."
  type        = string
}

variable "ecs_sg_id" {
  type = string
}

variable "aws_ecs_cluster" {
  type = object({
    name = string
    arn  = string
  })
}

variable "services" {
  type = list(object({
    tag       = string
    name      = string
    mem       = number
    cpu       = number
    ports     = list(number)
    essential = bool
    image     = bool
    image_id  = optional(string)

    environment = list(object({
      name  = string
      value = string
    }))

    command = list(string)
    dependsOn = list(object({
      containerName = string
      condition     = string
    }))

    healthCheck = object({
      command     = list(string)
      retries     = number
      timeout     = number
      interval    = number
      startPeriod = number
    })

    mountPoints = list(object({
      sourceVolume  = string
      containerPath = string
    }))

    ulimits = list(object({
      name      = string
      hardLimit = number
      softLimit = number
    }))
  }))
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "health_check_url" {
  type    = string
  default = "/healthcheck/"
}

variable "certificate_arn" {
  type    = string
  default = ""
}

variable "enable_https" {
  default = true
  type    = bool
}

variable "cloudwatch_alarm_name" {
  description = "Generic name used for CPU and Memory Cloudwatch Alarms"
  default     = ""
  type        = string
}

variable "cloudwatch_alarm_actions" {
  description = "The list of actions to take for cloudwatch alarms"
  type        = list(string)
  default     = []
}

variable "cloudwatch_alarm_cpu_enable" {
  description = "Enable the CPU Utilization CloudWatch metric alarm"
  default     = true
  type        = bool
}

variable "cloudwatch_alarm_cpu_threshold" {
  description = "The CPU Utilization threshold for the CloudWatch metric alarm"
  default     = 80
  type        = number
}

variable "cloudwatch_alarm_mem_enable" {
  description = "Enable the Memory Utilization CloudWatch metric alarm"
  default     = true
  type        = bool
}

variable "cloudwatch_alarm_mem_threshold" {
  description = "The Memory Utilization threshold for the CloudWatch metric alarm"
  default     = 80
  type        = number
}

variable "logs_cloudwatch_retention" {
  description = "Number of days you want to retain log events in the log group."
  default     = 365
  type        = number
}

variable "logs_cloudwatch_group" {
  description = "CloudWatch log group to create and use. Default: /ecs/{name}-{environment}"
  default     = ""
  type        = string
}

variable "ecr_repo_arns" {
  description = "The ARNs of the ECR repos.  By default, allows all repositories."
  type        = list(string)
  default     = ["*"]
}

variable "ecs_use_fargate" {
  description = "Whether to use Fargate for the task definition."
  default     = false
  type        = bool
}

variable "ecs_instance_role" {
  description = "The name of the ECS instance role."
  default     = ""
  type        = string
}

variable "ecs_vpc_id" {
  description = "VPC ID to be used by ECS."
  type        = string
}

variable "ecs_private_subnets" {
  description = "Subnet IDs for the ECS tasks."
  type        = list(string)
}

variable "ecs_public_subnets" {
  type = list(string)
}

variable "ec2_create_task_execution_role" {
  description = "Set to true to create ecs task execution role to ECS EC2 Tasks."
  type        = bool
  default     = true
}

variable "assign_public_ip" {
  description = "Whether this instance should be accessible from the public internet. Default is false."
  default     = false
  type        = bool
}

variable "internal" {
  description = "Whether this instance should have a load balancer that resolves to a private ip address."
  default     = false
  type        = bool
}

variable "fargate_platform_version" {
  description = "The platform version on which to run your service. Only applicable when using Fargate launch type."
  default     = "LATEST"
  type        = string
}

variable "fargate_task_cpu" {
  description = "Number of cpu units used in initial task definition. Default is minimum."
  type        = number
  default     = 4096
}

variable "fargate_task_memory" {
  description = "Amount (in MiB) of memory used in initial task definition. Default is minimum."
  type        = number
  default     = 16384
}

variable "tasks_desired_count" {
  description = "The number of instances of a task definition."
  default     = 1
  type        = number
}

variable "tasks_minimum_healthy_percent" {
  description = "Lower limit on the number of running tasks."
  default     = 100
  type        = number
}

variable "tasks_maximum_percent" {
  description = "Upper limit on the number of running tasks."
  default     = 200
  type        = number
}

variable "container_definitions" {
  description = "Container definitions provided as valid JSON document. Default uses golang:alpine running a simple hello world."
  default     = ""
  type        = string
}

variable "target_container_name" {
  description = "Name of the container the Load Balancer should target. Default: {name}-{environment}"
  default     = "frontend"
  type        = string
}

variable "associate_alb" {
  description = "Whether to associate an Application Load Balancer (ALB) with the ECS service."
  default     = false
  type        = bool
}

variable "associate_nlb" {
  description = "Whether to associate a Network Load Balancer (NLB) with the ECS service."
  default     = false
  type        = bool
}

variable "alb_security_group" {
  description = "Application Load Balancer (ALB) security group ID to allow traffic from."
  default     = ""
  type        = string
}

variable "nlb_subnet_cidr_blocks" {
  description = "List of Network Load Balancer (NLB) CIDR blocks to allow traffic from."
  default     = []
  type        = list(string)
}

variable "additional_security_group_ids" {
  description = "In addition to the security group created for the service, a list of security groups the ECS service should also be added to."
  default     = []
  type        = list(string)
}

variable "lb_target_groups" {
  description = "List of load balancer target group objects containing the lb_target_group_arn, container_port and container_health_check_port. The container_port is the port on which the container will receive traffic. The container_health_check_port is an additional port on which the container can receive a health check. The lb_target_group_arn is either Application Load Balancer (ALB) or Network Load Balancer (NLB) target group ARN tasks will register with."
  default     = []
  type = list(
    object({
      container_port              = number
      container_health_check_port = number
      lb_target_group_arn         = string
      }
    )
  )
}

variable "container_port" {
  default     = 443
  description = "Port for the container app to listen on. The app currently supports listening on two ports."
  type        = number

}

variable "service_registries" {
  description = "List of service registry objects as per <https://www.terraform.io/docs/providers/aws/r/ecs_service.html#service_registries-1>. List can only have a single object until <https://github.com/terraform-providers/terraform-provider-aws/issues/9573> is resolved."
  type = list(object({
    registry_arn   = string
    container_name = string
  }))
  default = []
}

variable "health_check_grace_period_seconds" {
  description = "Grace period within which failed health checks will be ignored at container start. Only applies to services with an attached loadbalancer."
  default     = 30
  type        = number
}

variable "ecs_exec_enable" {
  description = "Enable the ability to execute commands on the containers via Amazon ECS Exec"
  default     = false
  type        = bool
}
