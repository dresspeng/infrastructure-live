include {
  path = find_in_parent_folders()
}

locals {
  convention_tmp_vars = read_terragrunt_config(find_in_parent_folders("convention_override.hcl"))
  convention_vars     = read_terragrunt_config(find_in_parent_folders("convention.hcl"))
  account_vars        = read_terragrunt_config(find_in_parent_folders("account_override.hcl"))
  organization_vars   = read_terragrunt_config("${get_terragrunt_dir()}/organization.hcl")

  modules_branch_name = local.convention_tmp_vars.locals.modules_branch_name

  modules_git_prefix = local.convention_vars.locals.modules_git_prefix

  account_region_name = local.account_vars.locals.account_region_name
  account_name        = local.account_vars.locals.account_name
  account_id          = local.account_vars.locals.account_id

  github = local.organization_vars.locals.github
  aws = merge(
    local.organization_vars.locals.aws,
    {
      tags = merge(
        local.convention_tmp_vars.locals.tags,
        local.account_vars.locals.tags,
        local.organization_vars.locals.aws.tags,
      )
    }
  )
}

terraform {
  source = "${local.modules_git_prefix}//projects/module/_global/level?ref=${local.modules_branch_name}"
}

inputs = {
  aws    = local.aws
  github = local.github
}
