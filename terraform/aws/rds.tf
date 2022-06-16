locals {
  name = "${var.name}-${var.environment}-postgres"
}

################################################################################
# RDS Module
################################################################################

# The analysis database must be initialized with init_db.sh before it will work with the analysis service

resource "aws_db_instance" "postgres" {
  max_allocated_storage    = 60
  allocated_storage        = 12
  engine                   = "postgres"
  engine_version           = "13.6"
  instance_class           = "db.t4g.small" # Adjust as needed. We suggest Graviton instances (t4g) for better price/performance.
  identifier               = local.name
  name                     = "keycloak"
  username                 = "keycloak"
  password                 = random_password.keycloak_database.result
  skip_final_snapshot      = true
  deletion_protection      = false
  delete_automated_backups = false
  backup_window            = "10:00-11:00"
  backup_retention_period  = 21
  db_subnet_group_name     = var.database_subnet_group_name != null ? var.database_subnet_group_name : var.name
  vpc_security_group_ids   = [aws_security_group.keycloak-security-group.id]
  storage_encrypted        = true

  tags = {
    Name        = var.name
    Environment = var.environment
    Automation  = "Terraform"
  }
}

################################################################################
# Security
################################################################################

resource "aws_security_group" "keycloak-security-group" {
  name = "${local.name}-security-group"

  description = "Security group to RDS (terraform) for secoda-${local.name}"
  vpc_id      = var.vpc_id == null ? module.vpc[0].vpc_id : var.vpc_id

  # Only PG in.
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }

  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = var.name
    Environment = var.environment
    Automation  = "Terraform"
  }
}
