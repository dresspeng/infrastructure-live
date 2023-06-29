locals {
  convention_vars = read_terragrunt_config(find_in_parent_folders("convention_override.hcl"))
  account_vars    = read_terragrunt_config(find_in_parent_folders("account_override.hcl"))

  organization_name = local.convention_vars.locals.organization_name
  environment_name  = local.convention_vars.locals.environment_name

  account_region_name = local.account_vars.locals.account_region_name
  account_name        = local.account_vars.locals.account_name
  account_id          = local.account_vars.locals.account_id
}

# Generate version block
generate "versions" {
  path      = "version_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 5.5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "= 3.2.1"
    }
  }
  required_version = ">= 1.4.0"
}
EOF
}

# Generate provider block
generate "provider" {
  path      = "provider_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.account_region_name}"
  allowed_account_ids = ["${local.account_id}"]
}
EOF
}

# Configure Terragrunt to automatically store tfstate files in an S3 bucket
remote_state {
  # Added for backwards compatibility. This should default to false, so that existing config overrides completely as
  # opposed to partially.
  # merge_parent = false

  backend = "s3"
  config = {
    encrypt        = true
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.account_region_name
    bucket         = lower("${local.organization_name}-${local.environment_name}-terraform-state")
    dynamodb_table = lower("${local.organization_name}-${local.environment_name}-terraform-locks")
  }

  generate = {
    path      = "backend_override.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Extra arguments when running commands
terraform {
  # Force Terraform to keep trying to acquire a lock for up to 20 minutes if someone else already has the lock
  extra_arguments "retry_lock" {
    commands  = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=20m"]
  }
}
