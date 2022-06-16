module "manifest_bucket" {
  source      = "./s3"
  environment = var.environment
  name        = "secoda-private-${substr(random_uuid.bucket.result, 0, 4)}" # Use a few characters to ensure uniqueness
  acl         = "private"
}

resource "random_uuid" "bucket" {}
