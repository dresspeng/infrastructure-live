for_each = read_terragrunt_config("region_override.hcl").locals.region_names

locals {
  convention_vars = read_terragrunt_config(find_in_parent_folders("convention_override.hcl"))
  account_vars    = read_terragrunt_config(find_in_parent_folders("account_override.hcl"))

  organization_name = local.convention_vars.locals.organization_name
  environment_name  = local.convention_vars.locals.environment_name

  account_region_names = local.account_vars.locals.account_region_names
  account_name         = local.account_vars.locals.account_name
  account_id           = local.account_vars.locals.account_id
}

# Generate an AWS provider block
generate "provider" {
  path      = "provider_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region                = "${each.value}"
  allowed_account_ids   = ["${local.aws_account_id}"]
}
EOF
}

# Configure Terragrunt to automatically store tfstate files in an S3 bucket
remote_state {
  # Added for backwards compatibility. This should default to false, so that existing config overrides completely as
  # opposed to partially.
  merge_parent = false

  backend = "s3"
  config = {
    encrypt        = true
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = each.value
    bucket         = lower("${local.organization_name}-${local.account_name}-${local.environment_name}-terraform-state")
    dynamodb_table = lower("${local.organization_name}-${local.account_name}-${local.environment_name}-terraform-locks")
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
