include {
  path = find_in_parent_folders()
}

locals {
  convention_tmp_vars = read_terragrunt_config(find_in_parent_folders("convention_override.hcl"))
  convention_vars     = read_terragrunt_config(find_in_parent_folders("convention.hcl"))
  account_vars        = read_terragrunt_config(find_in_parent_folders("account_override.hcl"))
  config = yamldecode(
    templatefile(
      "${get_terragrunt_dir()}/config.yml",
      {
        SSH_PUBLIC_KEY  = get_env("SSH_PUBLIC_KEY")
        GH_TERRA_TOKEN  = get_env("GITHUB_TOKEN")
        SSH_PRIVATE_KEY = get_env("SSH_PRIVATE_KEY")
        VPC_ID          = get_env("VPC_ID")
      }
    )
  )

  modules_branch_name = local.convention_tmp_vars.locals.modules_branch_name

  modules_git_prefix = local.convention_vars.locals.modules_git_prefix

  account_region_name = local.account_vars.locals.account_region_name
  account_name        = local.account_vars.locals.account_name
  account_id          = local.account_vars.locals.account_id
}

terraform {
  source = "${local.modules_git_prefix}//modules/github/variables?ref=${local.modules_branch_name}"
}

inputs = local.config
