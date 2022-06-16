################################################################################
# Networking
################################################################################

data "aws_availability_zones" "available" {
  state = "available"
}

# If a VPC ID is provided, use that. Otherwise, create a VPC.
data "aws_vpc" "override" {
  count = var.vpc_id != null ? 1 : 0
  id    = var.vpc_id
}
module "vpc" {

  count   = var.vpc_id == null ? 1 : 0
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = var.name
  cidr = var.cidr

  create_database_subnet_group    = true
  create_elasticache_subnet_group = false

  # All services except for the load balancer sit in private subnets.
  # They require a NAT gateway to communicate with the internet.
  enable_nat_gateway = true
  single_nat_gateway = true

  manage_default_route_table = true
  default_route_table_tags   = { DefaultRouteTable = true }

  azs              = var.aws_availability_zones != null ? var.aws_availability_zones : [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  public_subnets   = var.public_subnets_blocks
  private_subnets  = var.private_subnets_blocks
  database_subnets = var.database_subnets_blocks

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Skip creation of EIPs for the NAT Gateways. This will preserve the EIP across resets.
  reuse_nat_ips       = true
  external_nat_ip_ids = aws_eip.nat.*.id
}

resource "aws_eip" "nat" {
  count = 1
  vpc   = true
}
