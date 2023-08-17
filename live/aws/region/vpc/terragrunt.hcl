include {
  path = find_in_parent_folders()
}

locals {
  convention_tmp_vars = read_terragrunt_config(find_in_parent_folders("convention_override.hcl"))
  convention_vars     = read_terragrunt_config(find_in_parent_folders("convention.hcl"))
  account_vars        = read_terragrunt_config(find_in_parent_folders("account_override.hcl"))
  vpc_vars            = read_terragrunt_config("${get_terragrunt_dir()}/vpc.hcl")

  override_extension_name       = local.convention_tmp_vars.locals.override_extension_name
  modules_git_host_auth_method  = local.convention_tmp_vars.locals.modules_git_host_auth_method
  modules_git_host_name         = local.convention_tmp_vars.locals.modules_git_host_name
  modules_organization_name     = local.convention_tmp_vars.locals.modules_organization_name
  modules_repository_name       = local.convention_tmp_vars.locals.modules_repository_name
  modules_repository_visibility = local.convention_tmp_vars.locals.modules_repository_visibility
  modules_branch_name           = local.convention_tmp_vars.locals.modules_branch_name

  modules_git_prefix = local.convention_vars.locals.modules_git_prefix

}

terraform {
  source = "${local.modules_git_prefix}//module/aws/network/vpc?ref=${local.modules_branch_name}"
}

inputs = {
  name      = local.vpc_vars.locals.name
  cidr_ipv4 = local.vpc_vars.locals.cidr_ipv4
  # nat       = local.vpc_vars.locals.nat
  tags = merge(
    local.convention_tmp_vars.locals.tags,
    local.account_vars.locals.tags,
    local.vpc_vars.locals.tags,
  )
}
