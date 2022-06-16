# Copy this file to onprem.tfvars and fill it.

################################################################################
# Required
# These must be set before running for the first time.
################################################################################

# This will be provided by customer support.
docker_password = "********"

################################################################################
# Optional
# These can be set if you want to override the defaults.
################################################################################

# name="secoda"
# environment="on-premise"

# Fill with your preferred region. This needs to match the AWS_REGION that prefixes the `terraform apply` command.
# aws_region = "us-east-1

# You may enable a custom domain with a valid certificate for the terminating TLS on the application load balancer.
# certificate_arn = "<VALID_CERTIFICATE_ARN_FOR_BASE_DOMAIN>" # If you would like to use a custom certificate, set and fill with the proper arn.

# If VPC is being overridden, you must set the VPC id and the subnet parameters below (all of these vars).
# There must be at least 2 public subnets and 2 private subnets in the VPC.
# vpc_id = "vpc-******"
# private_subnets = ["subnet-******", "subnet-******"]
# public_subnets = ["subnet-******", "subnet-******"]
# These can be unique or the same as the private subnets.
# database_subnets = ["subnet-******", "subnet-******"] 
# This subnet group should encompass the database_subnets.
# database_subnet_group_name = "secoda-on-premise"
# aws_availability_zones = ["us-east-1a", "us-east-1b"]
