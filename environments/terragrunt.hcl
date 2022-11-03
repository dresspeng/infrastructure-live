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

terraform {
  # Force Terraform to keep trying to acquire a lock for up to 20 minutes if someone else already has the lock
  extra_arguments "retry_lock" {
    commands  = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=20m"]
  }

  # Pass the environment variables in a file
  extra_arguments "common_vars" {
    commands = get_terraform_commands_that_need_locking()
    required_var_files = [
      "-var-file=environment.tfvars",
    ]
  }
}

iam_role = "arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME"

# remote_state {
#   backend = "s3"
#   generate = {
#     path      = "backend.tf"
#     if_exists = "overwrite_terragrunt"
#   }
#   config = {
#     bucket         = "terraform-state-backend-production-storage"
#     key            = "${path_relative_to_include()}/terraform.tfstate" # automatically set key to the relative path between the root terragrunt.hcl and the child module
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "terraform-state-backend-production-locks"
#   }
# }