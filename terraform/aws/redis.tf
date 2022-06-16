module "this" {
  source    = "cloudposse/label/null"
  version   = "0.25.0"
  namespace = "secoda"
  stage     = "production"
  name      = var.name
}


module "redis" {
  source  = "cloudposse/elasticache-redis/aws"
  version = "0.42.0"

  replication_group_id = "${var.name}-rg-queue"

  availability_zones = var.aws_availability_zones != null ? var.aws_availability_zones : [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  vpc_id             = var.vpc_id == null ? module.vpc[0].vpc_id : var.vpc_id

  allowed_security_group_ids = [aws_security_group.ecs_sg.id]
  subnets                    = var.vpc_id == null ? module.vpc[0].database_subnets : var.database_subnets
  cluster_size               = 1
  instance_type              = "cache.t4g.micro"
  apply_immediately          = true
  automatic_failover_enabled = false
  engine_version             = "6.x"
  family                     = "redis6.x"
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.redis.result
  context                    = module.this.context
}

resource "random_password" "redis" {
  length  = 16
  special = false
}
