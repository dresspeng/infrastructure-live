# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

locals {
  # Automatically load region-level variables
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Automatically load environment-level variables
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  # Extract out common variables for reuse
  aws_region       = local.region_vars.locals.aws_region
  environment_name = local.environment_vars.locals.environment_name
  common_tags      = { Region: local.aws_region, Environment: local.environment_name, Project : "Scraper" }
  vpc_cidr_ipv4 = local.environment_vars.locals.vpc_cidr_ipv4
}

dependencies {
  paths = ["../backend"]
}

terraform {
  source = "git::git@github.com:KookaS/infrastructure-modules.git//modules/vpc"
}

inputs = {
  project_name     = "scraper"
  environment_name = local.environment_name
  common_tags      = local.common_tags
  vpc_cidr_ipv4    = local.vpc_cidr_ipv4
}
