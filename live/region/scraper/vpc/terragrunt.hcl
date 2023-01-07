include {
  path = find_in_parent_folders()
}

locals {
  account_vars     = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl"))

  # global
  aws_account_name          = local.account_vars.locals.aws_account_name
  github_organization       = local.account_vars.locals.github_organization
  github_modules_repository = local.account_vars.locals.github_modules_repository
  github_modules_branch     = local.account_vars.locals.github_modules_branch
  aws_region                = local.region_vars.locals.aws_region
  project_name              = local.environment_vars.locals.project_name
  environment_name          = local.environment_vars.locals.environment_name
  vpc_cidr_ipv4             = local.environment_vars.locals.vpc_cidr_ipv4
  enable_nat                = local.environment_vars.locals.enable_nat
  common_name               = "${local.project_name}-${local.environment_name}"
}

terraform {
  source = "git::git@github.com:${local.github_organization}/${local.github_modules_repository}.git//modules/vpc?ref=${local.github_modules_branch}"
}

inputs = {
  aws_region    = local.aws_region
  vpc_name      = local.common_name
  common_tags   = { Region : local.aws_region, Account : local.aws_account_name, Environment : local.environment_name }
  vpc_cidr_ipv4 = local.vpc_cidr_ipv4
  enable_nat    = local.enable_nat
}
