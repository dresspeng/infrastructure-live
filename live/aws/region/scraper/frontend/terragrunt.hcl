include {
  path = find_in_parent_folders()
}

locals {
  convention_tmp_vars = read_terragrunt_config(find_in_parent_folders("convention_override.hcl"))
  convention_vars     = read_terragrunt_config(find_in_parent_folders("convention.hcl"))
  account_vars        = read_terragrunt_config(find_in_parent_folders("account_override.hcl"))
  microservice_vars   = read_terragrunt_config(find_in_parent_folders("microservice.hcl"))
  service_tmp_vars    = read_terragrunt_config("${get_terragrunt_dir()}/service_override.hcl")

  override_extension_name       = local.convention_tmp_vars.locals.override_extension_name
  modules_git_host_auth_method  = local.convention_tmp_vars.locals.modules_git_host_auth_method
  modules_git_host_name         = local.convention_tmp_vars.locals.modules_git_host_name
  modules_organization_name     = local.convention_tmp_vars.locals.modules_organization_name
  modules_repository_name       = local.convention_tmp_vars.locals.modules_repository_name
  modules_repository_visibility = local.convention_tmp_vars.locals.modules_repository_visibility
  modules_branch_name           = local.convention_tmp_vars.locals.modules_branch_name

  modules_git_prefix = local.convention_vars.locals.modules_git_prefix

  domain_name         = local.account_vars.locals.domain_name
  domain_suffix       = local.account_vars.locals.domain_suffix
  account_region_name = local.account_vars.locals.account_region_name
  account_name        = local.account_vars.locals.account_name
  account_id          = local.account_vars.locals.account_id

  branch_name = local.service_tmp_vars.locals.branch_name

  config_override = yamldecode(file("${get_terragrunt_dir()}/config_override.yml"))
  config = yamldecode(
    templatefile(
      "${get_terragrunt_dir()}/config.yml",
      {
        vpc_id      = get_env("VPC_ID")
        branch_name = local.branch_name
        port        = local.config_override.port
      }
    )
  )
}

terraform {
  source = "${local.modules_git_prefix}//projects/module/aws/projects/scraper/frontend?ref=${local.modules_branch_name}"
}

inputs = {
  name_prefix = lower(substr(local.convention_tmp_vars.locals.organization_name, 0, 2))
  name_suffix = lower(join("-", [local.account_name, join("-", [for str in split("-", local.account_region_name) : substr(str, 0, 1)]), local.branch_name]))


  vpc = local.config.vpc

  microservice = {
    iam = local.config.iam

    route53 = {
      zones = [
        {
          name = "${local.domain_name}.${local.domain_suffix}"
        }
      ]
      record = {
        prefixes       = ["www"]
        subdomain_name = format("%s%s", local.branch_name == "trunk" ? "" : "${local.branch_name}.", local.config.repository_name)
      }
    }

    bucket_env = merge(
      local.config.bucket_env,
      {
        file_path = "${get_terragrunt_dir()}/${local.override_extension_name}.env"
      }
    )

    container = local.config.microservice.container
  }

  tags = merge(
    local.convention_tmp_vars.locals.tags,
    local.account_vars.locals.tags,
    local.config.tags,
  )
}
