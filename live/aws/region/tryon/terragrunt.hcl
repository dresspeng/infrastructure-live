locals {
  convention_tmp_vars = read_terragrunt_config(find_in_parent_folders("convention_override.hcl"))
  convention_vars     = read_terragrunt_config(find_in_parent_folders("convention_override.hcl"))
  account_vars        = read_terragrunt_config(find_in_parent_folders("account_override.hcl"))
  service_tmp_vars    = read_terragrunt_config("${get_terragrunt_dir()}/service_override.hcl")

  account_region_name = local.account_vars.locals.account_region_name
  account_name        = local.account_vars.locals.account_name
  account_id          = local.account_vars.locals.account_id

  branch_name = local.service_tmp_vars.locals.branch_name


  path = regex("^.*/(?P<project_name>[0-9A-Za-z!_-]+)/(?P<service_name>[0-9A-Za-z!_-]+)$", get_terragrunt_dir())
  # organization_name_s  = substr(local.convention_tmp_vars.locals.organization_name, 0, 2)
  project_name_s = substr(local.path.project_name, 0, 2)
  service_name_s = substr(local.path.service_name, 0, 2)
  branch_name_s  = substr(local.branch_name, 0, 2)
  account_name_s = substr(local.account_name, 0, 2)
  region_name_s  = join("", [for str in split("-", local.account_region_name) : substr(str, 0, 1)])
  name           = lower(join("-", [local.project_name_s, local.service_name_s, local.branch_name_s, local.account_name_s, local.region_name_s]))

  backend_bucket_name         = "${local.name}-tf-state"
  backend_dynamodb_table_name = "${local.name}-tf-locks"
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
          version = "~> 5.5.0"
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
  backend = "s3"
  config = {
    encrypt        = true
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.account_region_name
    bucket         = local.backend_bucket_name
    dynamodb_table = local.backend_dynamodb_table_name
    # s3_bucket_tags      = local.tags
    # dynamodb_table_tags = local.tags
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
