# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION BLOCKS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  # # Automatically load account-level variables
  # account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  # # Automatically load region-level variables
  # region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # # Automatically load environment-level variables
  # environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl"))

    # Automatically load account-level variables
  account_vars = read_terragrunt_config("${get_terragrunt_dir()}/live/account.hcl")

  # Automatically load region-level variables
  region_vars = read_terragrunt_config("${get_terragrunt_dir()}/live/region/region.hcl")

  # Automatically load environment-level variables
  environment_vars = read_terragrunt_config("${get_terragrunt_dir()}/live/region/environment/environment.hcl")

  # Extract the variables we need for easy access
  aws_profile      = local.account_vars.locals.aws_profile
  aws_account_id   = local.account_vars.locals.aws_account_id
  aws_role_name    = local.account_vars.locals.aws_role_name
  aws_region       = local.region_vars.locals.aws_region
  environment_name = local.environment_vars.locals.environment_name
}

# Generate a Terraform and AWS version block
generate "versions" {
  path      = "versions_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
    terraform {
      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 4.16"
        }
      }
      required_version = ">= 1.2.0"
    }
EOF
}

# Generate an AWS provider block
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"
  
  # Only these AWS Account IDs may be operated on by this template
  allowed_account_ids = ["${local.aws_account_id}"]
}
EOF
}

# Configure Terragrunt to automatically store tfstate files in an S3 bucket
remote_state {
  backend = "s3"
  config = {
    encrypt        = true
    bucket         = "${get_env("TG_BUCKET_PREFIX", "")}terraform-state-${local.environment_name}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    dynamodb_table = "${get_env("TG_BUCKET_PREFIX", "")}terraform-locks-${local.environment_name}"
  }
  generate = {
    path      = "backend.tf"
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

# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION ATTRIBUTES
# ---------------------------------------------------------------------------------------------------------------------
# iam_role = "arn:aws:iam::${local.aws_account_id}:role/${local.aws_role_name}"

inputs = merge(
  local.account_vars.locals,
  local.region_vars.locals,
  local.environment_vars.locals,
  # {
  #   common_tags = { Region : local.aws_region, Environment : local.environment_name }
  # }
)
