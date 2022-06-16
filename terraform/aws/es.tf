resource "random_password" "es" {
  length           = 16
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
  special          = true
  override_special = "$"
}
resource "aws_elasticsearch_domain" "secoda" {
  domain_name           = var.name
  elasticsearch_version = "7.10"
  cluster_config {
    instance_type = "t3.small.elasticsearch" # Adjust as needed.
  }

  encrypt_at_rest {
    enabled = true
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 12 # Adjust as needed. Valid >= 12GB.
    volume_type = "gp2"
  }

  vpc_options {
    subnet_ids         = [var.vpc_id == null ? module.vpc[0].private_subnets[0] : var.private_subnets[0]]
    security_group_ids = [aws_security_group.es.id]
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true

    master_user_options {
      master_user_name     = var.es_username
      master_user_password = random_password.es.result
    }
  }

  # Enable basic http auth
  access_policies = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "*"
        ]
      },
      "Action": [
        "es:ESHttp*"
      ],
      "Resource": "arn:aws:es:${var.aws_region}:${data.aws_caller_identity.current.account_id}:domain/${var.name}/*"
    }
  ]
}
  POLICY

  depends_on = [aws_iam_service_linked_role.es]
}

resource "aws_security_group" "es" {
  name        = "${var.name}-elasticsearch"
  description = "Managed by Terraform"
  vpc_id      = var.vpc_id == null ? module.vpc[0].vpc_id : var.vpc_id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }

  tags = {
    Name        = var.name
    Environment = var.environment
    Automation  = "Terraform"
  }
}

resource "aws_iam_service_linked_role" "es" {
  aws_service_name = "es.amazonaws.com"
}

data "aws_caller_identity" "current" {}
