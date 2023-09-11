locals {
  convention_tmp_vars = read_terragrunt_config(find_in_parent_folders("convention_override.hcl"))
  convention_vars     = read_terragrunt_config(find_in_parent_folders("convention_override.hcl"))
  account_vars        = read_terragrunt_config(find_in_parent_folders("account_override.hcl"))

  account_region_name = local.account_vars.locals.account_region_name
  account_name        = local.account_vars.locals.account_name
  account_id          = local.account_vars.locals.account_id

  name_prefix                 = lower(substr(local.convention_tmp_vars.locals.organization_name, 0, 2))
  backend_bucket_name         = lower(join("-", compact([local.name_prefix, local.account_region_name, "tf-state"])))
  backend_dynamodb_table_name = lower(join("-", compact([local.name_prefix, local.account_region_name, "tf-locks"])))

  tags = merge(
    local.convention_vars.locals.tags,
  )
}

# Generate version block
generate "versions" {
  path      = "version_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
    terraform {
      required_version = ">= 1.4.0"
    }
  EOF
}

# TODO: add ecr account for private repos
# Generate provider block
generate "provider" {
  path      = "provider_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
    provider "github" {
      version = "~> 5.0"
      token = "${get_env("GITHUB_TOKEN")}"
    }
  EOF
}

# Configure Terragrunt to automatically store tfstate files in an S3 bucket
remote_state {
  backend = "s3"
  config = {
    encrypt             = true
    key                 = "${path_relative_to_include()}/terraform.tfstate"
    region              = local.account_region_name
    bucket              = local.backend_bucket_name
    dynamodb_table      = local.backend_dynamodb_table_name
    s3_bucket_tags      = local.tags
    dynamodb_table_tags = local.tags
  }

  generate = {
    path      = "backend_override.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Extra arguments when running commands
terraform {
  # Force Terraform to keep trying to acquire a lock for some minutes if someone else already has the lock
  extra_arguments "retry_lock" {
    commands  = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=10m"]
  }
}
