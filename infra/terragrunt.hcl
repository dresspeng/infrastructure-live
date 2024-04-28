locals {
  convention_vars = read_terragrunt_config("convention.hcl")

  root_path     = trimsuffix(get_repo_root(), "/")
  domain_prefix = local.convention_vars.locals.environment == "prod" ? null : local.convention_vars.locals.environment
  domain_name   = get_env("DOMAIN_NAME")
}

generate "versions" {
  path      = "version_override.tf"
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

generate "provider" {
  path      = "provider_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
# Main region where the resources should be created in
# Should be close to the location of your viewers
provider "aws" {
  region = "${local.convention_vars.locals.account_region_name}"
  # Make it faster by skipping something
  # skip_metadata_api_check     = true
  # skip_region_validation      = true
  # skip_credentials_validation = true
}
EOF
}

remote_state {
  backend = "s3"
  config = {
    encrypt = true
    # key                 = "${path_relative_to_include()}/terraform.tfstate"
    key                 = "terraform.tfstate"
    region              = local.convention_vars.locals.account_region_name
    bucket              = lower(join("-", compact([local.convention_vars.locals.name, "tf-state"])))
    dynamodb_table      = lower(join("-", compact([local.convention_vars.locals.name, "tf-locks"])))
    s3_bucket_tags      = local.convention_vars.locals.tags
    dynamodb_table_tags = local.convention_vars.locals.tags
  }

  generate = {
    path      = "backend_override.tf"
    if_exists = "overwrite_terragrunt"
  }
}

terraform {
  # Force Terraform to keep trying to acquire a lock for some minutes if someone else already has the lock
  extra_arguments "retry_lock" {
    commands  = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=10m"]
  }

  source = "."
}

inputs = {
  domain = {
    zone   = local.domain_name
    prefix = local.domain_prefix
  }

  tags = {
    Name        = local.convention_vars.locals.name
    Environment = local.convention_vars.locals.environment
    Terraform   = true
  }
}
