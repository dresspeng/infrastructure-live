# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

locals {
  # Automatically load environment-level variables
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl"))

  # Extract out common variables for reuse
  environment_name = local.environment_vars.locals.environment_name
}

terraform {
  source = "git::git@github.com:KookaS/infrastructure-modules.git//modules/backend"
}

inputs = {
  backend_name = "terraform-state-backend-${local.environment_name}"
}
