
################################################################################
# License
################################################################################

# Our customer support will provide you with a docker password.
variable "docker_password" {
  type = string
}

################################################################################
# VPC Override
################################################################################

variable "vpc_id" {
  type    = string
  default = null
}
variable "private_subnets" {
  type    = list(string)
  default = null
}

variable "public_subnets" {
  type    = list(string)
  default = null
}

variable "database_subnets" {
  type    = list(string)
  default = null
}

variable "database_subnet_group_name" {
  type    = string
  default = null
}

variable "aws_availability_zones" {
  type    = list(string)
  default = null
}

################################################################################
# General Networking
################################################################################

variable "cidr" {
  type    = string
  default = "10.9.0.0/16"
}

variable "private_subnets_blocks" {
  type    = list(string)
  default = ["10.9.0.0/24", "10.9.1.0/24"]
}

variable "public_subnets_blocks" {
  type    = list(string)
  default = ["10.9.4.0/24", "10.9.5.0/24"]
}

variable "database_subnets_blocks" {
  type    = list(string)
  default = ["10.9.8.0/24", "10.9.9.0/24"]
}

################################################################################
# Environment
################################################################################

# You may overwrite by setting `environment=` in the `tfvars` file.
variable "environment" {
  type    = string
  default = "on-premise"
}

# You may overwrite by setting `name=` in the `tfvars` file.
variable "name" {
  type    = string
  default = "secoda"
}

# May be modified to suit compliance needs.
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

################################################################################
# Authentication
################################################################################

variable "keycloak_secret_key" {
  type    = string
  default = null
}

variable "keycloak_admin_password" {
  type    = string
  default = null
}

################################################################################
# Load Balancers
################################################################################

# This may be modified. Note that if it is set to false, you will only be able to access the load balancer from within the AWS VPC subnet network.
variable "public_access" {
  type    = bool
  default = false
}

variable "certificate_arn" {
  type    = string
  default = ""
}

################################################################################
# Containers
################################################################################

# If you are not familiar with terraform, do not modify these services without consulting Secoda.
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

  default = [
    {
      tag         = "3"
      name        = "api"
      mem         = 6144
      cpu         = 1536
      ports       = [5007]
      essential   = true
      image       = false
      environment = []
      command     = null
      dependsOn = [
        {
          "containerName" = "auth"
          "condition"     = "HEALTHY"
        }
      ]
      healthCheck = {
        "retries" : 3,
        "command" : [
          "CMD-SHELL",
          "curl -f http://localhost:5007/healthcheck/ || exit 1"
        ],
        "timeout" : 5,
        "interval" : 5,
        "startPeriod" : 30
      }
      mountPoints = null
      ulimits     = null
    },
    {
      tag         = "4"
      name        = "frontend"
      mem         = 1024
      cpu         = 256
      ports       = [443]
      essential   = true
      image       = false
      environment = []
      command     = null
      dependsOn = [
        {
          "containerName" = "auth"
          "condition"     = "HEALTHY"
        }
      ]
      healthCheck = null
      mountPoints = null
      ulimits     = null
    },
    {
      tag       = "4"
      name      = "auth"
      mem       = 1024
      cpu       = 256
      ports     = [8080, 8443]
      essential = true
      image     = false

      environment = [
        # v18
        {
          "name" : "KC_DB", # >= v18
          "value" : "postgres",
        },
        {
          "name" : "KC_DB_USERNAME", # >= v18
          "value" : "keycloak",
        },
        {
          "name" : "KEYCLOAK_ADMIN", # >= v18
          "value" : "admin",
        },
        # v16, but some are also used by other services, so cannot be retired yet.
        {
          "name" : "KEYCLOAK_USER",
          "value" : "admin",
        },
      ]
      command = [
        "start --auto-build --http-relative-path /auth --hostname-strict false --proxy edge --spi-login-protocol-openid-connect-legacy-logout-redirect-uri=true --import-realm"
      ]
      dependsOn = null
      healthCheck = {
        "retries" : 5,
        "command" : [
          "CMD-SHELL",
          "curl -f http://localhost:8080/auth/realms/secoda/.well-known/openid-configuration || exit 1"
        ],
        "timeout" : 5,
        "interval" : 10,
        "startPeriod" : 10
      }
      mountPoints = null
      ulimits     = null
    }
  ]
}
