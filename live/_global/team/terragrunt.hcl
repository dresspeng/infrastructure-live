include {
  path = find_in_parent_folders()
}

locals {
  convention_tmp_vars = read_terragrunt_config(find_in_parent_folders("convention_override.hcl"))
  convention_vars     = read_terragrunt_config(find_in_parent_folders("convention.hcl"))
  account_vars        = read_terragrunt_config(find_in_parent_folders("account_override.hcl"))
  team_vars           = read_terragrunt_config("${get_terragrunt_dir()}/team.hcl")

  override_extension_name       = local.convention_tmp_vars.locals.override_extension_name
  modules_git_host_auth_method  = local.convention_tmp_vars.locals.modules_git_host_auth_method
  modules_git_host_name         = local.convention_tmp_vars.locals.modules_git_host_name
  modules_organization_name     = local.convention_tmp_vars.locals.modules_organization_name
  modules_repository_name       = local.convention_tmp_vars.locals.modules_repository_name
  modules_repository_visibility = local.convention_tmp_vars.locals.modules_repository_visibility
  modules_branch_name           = local.convention_tmp_vars.locals.modules_branch_name

  modules_git_prefix = local.convention_vars.locals.modules_git_prefix

  account_region_name = local.account_vars.locals.account_region_name
  account_name        = local.account_vars.locals.account_name
  account_id          = local.account_vars.locals.account_id

  name   = local.team_vars.locals.name
  aws    = local.team_vars.locals.aws
  github = local.team_vars.locals.github
}

terraform {
  source = "${local.modules_git_prefix}//module/_global/team?ref=${local.modules_branch_name}"
}

inputs = {
  name = local.name

  aws = {
    admins        = local.aws.admins
    devs          = local.aws.devs
    machines      = local.aws.machines
    resources     = local.aws.resources
    store_secrets = true
    tags = merge(
      local.convention_tmp_vars.locals.tags,
      local.account_vars.locals.tags,
      local.team_vars.locals.tags,
    )
  }

  github = {
    repository_names  = local.github.repository_names
    store_environment = true
  }
}
