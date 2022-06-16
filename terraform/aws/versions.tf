terraform {
  experiments = [module_variable_optional_attrs]
  required_version = ">= 1.1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.74.3"
    }
  }

  # If using terraform cloud, you may uncomment the following:
  # backend "remote" {
  #   # If using terraform cloud, please replace `organization = "secoda"` with your organization name.
  #   organization = "secoda"
  #   workspaces {
  #     name = "secoda-on-premise"
  #   }
  # }
}
