# Generate a Terraform and AWS version block
generate "versions" {
  path      = "versions_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
    terraform {
      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = ">= 5.0.1"
        }
      }
      required_version = ">= 1.4.0"
    }
EOF
}