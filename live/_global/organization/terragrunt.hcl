include {
  path = find_in_parent_folders()
}

# TODO: Create backup before doing any changes
# TODO: plan before changes

locals {
  convention_tmp_vars = read_terragrunt_config(find_in_parent_folders("convention_override.hcl"))
  convention_vars     = read_terragrunt_config(find_in_parent_folders("convention.hcl"))
  account_vars        = read_terragrunt_config(find_in_parent_folders("account_override.hcl"))

  modules_branch_name = local.convention_tmp_vars.locals.modules_branch_name

  modules_git_prefix = local.convention_vars.locals.modules_git_prefix

  account_region_name = local.account_vars.locals.account_region_name
  account_name        = local.account_vars.locals.account_name
  account_id          = local.account_vars.locals.account_id

  name_prefix                 = substr(local.convention_tmp_vars.locals.organization_name, 0, 2)
  backend_bucket_name         = lower(join("-", compact([local.name_prefix, "tf-state"])))
  backend_dynamodb_table_name = lower(join("-", compact([local.name_prefix, "tf-locks"])))

  config = yamldecode(
    templatefile(
      "${get_terragrunt_dir()}/config.yml",
      {
        account_id                  = local.account_id
        backend_dynamodb_table_name = local.backend_dynamodb_table_name
        backend_bucket_name         = local.backend_bucket_name
      }
    )
  )
}

terraform {
  source = "${local.modules_git_prefix}//projects/module/_global/level?ref=${local.modules_branch_name}"
}

inputs = {
  name_prefix = local.name_prefix
  aws = merge(
    local.config.aws,
    {
      tags = merge(
        local.convention_tmp_vars.locals.tags,
        local.account_vars.locals.tags,
        local.config.aws.tags,
      )
    }
  )
  github = local.config.github
}
