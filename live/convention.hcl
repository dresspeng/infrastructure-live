locals {
  convention_tmp_vars = read_terragrunt_config("${get_terragrunt_dir()}/convention_override.hcl")

  modules_git_host_auth_method  = local.convention_tmp_vars.locals.modules_git_host_auth_method
  modules_git_host_name         = local.convention_tmp_vars.locals.modules_git_host_name
  modules_organization_name     = local.convention_tmp_vars.locals.modules_organization_name
  modules_repository_name       = local.convention_tmp_vars.locals.modules_repository_name
  modules_repository_visibility = local.convention_tmp_vars.locals.modules_repository_visibility

  modules_git_prefix = format("%s%s",
    local.modules_git_host_auth_method == "ssh" ? "git::git@${local.modules_git_host_name}:" : (
      local.modules_git_host_auth_method == "https" ? "git::https://${local.modules_repository_visibility == "private" ? "oauth2:${get_env("GITHUB_TOKEN")}@" : ""}${local.modules_git_host_name}/" : null
    ),
    "${local.modules_organization_name}/${local.modules_repository_name}.git"
  )
}
