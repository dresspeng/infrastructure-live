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
        branch_name = local.branch_name
      }
    )
  )

  name = lower(join("-", [local.account_name, local.branch_name]))

  env_local_path = "${get_terragrunt_dir()}/${local.override_extension_name}.env"
}

terraform {
  before_hook "env" {
    commands = ["init"]
    execute = [
      "/bin/bash",
      "-c",
      "echo COMMON_NAME=${local.name} >> ${local.env_local_path}"
    ]
  }

  source = "${local.modules_git_prefix}//projects/module/aws/projects/scraper/backend?ref=${local.modules_branch_name}"
}

inputs = {
  name_prefix = substr(local.convention_tmp_vars.locals.organization_name, 0, 2)
  name_suffix = local.name

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
        file_path = local.env_local_path
      }
    )

    ecs = merge(local.microservice_vars.locals.ecs, {
      traffics = [
        for traffic in local.config.ecs.traffics : {
          listener = {
            port     = try(traffic.listener.port, null)
            protocol = traffic.listener.protocol
          },
          target = {
            port              = try(traffic.listener.port, local.config_override.port)
            protocol          = traffic.target.protocol
            health_check_path = local.config_override.healthCheckPath
          }
        }
      ]
      service = merge(
        local.microservice_vars.locals.ecs.service,
        {
          deployment_type    = local.config.deployment_type
          task_min_count     = local.config.task_min_count
          task_desired_count = local.config.task_desired_count
          task_max_count     = local.config.task_max_count
          deployment_circuit_breaker = local.config.deployment_type == "ec2" ? {
            enable   = true
            rollback = true
          } : null
        }
      )
      task_definition = merge(
        local.microservice_vars.locals.ecs.task_definition,
        local.config.deployment_type == "fargate" ? {
          cpu                = local.microservice_vars.locals.fargate_instances[local.config.fargate_instance_key].cpu
          memory             = local.microservice_vars.locals.fargate_instances[local.config.fargate_instance_key].memory
          memory_reservation = null
          } : local.config.deployment_type == "ec2" ? {
          cpu                = local.microservice_vars.locals.ec2_instances[local.config.ec2_instance_key].cpu
          memory             = local.microservice_vars.locals.ec2_instances[local.config.ec2_instance_key].memory_allowed - local.microservice_vars.locals.ecs_reserved_memory
          memory_reservation = local.microservice_vars.locals.ec2_instances[local.config.ec2_instance_key].memory_allowed - local.microservice_vars.locals.ecs_reserved_memory
        } : null,
        local.config.ecs.task_definition,
      )
      ec2 = { for pricing_name in local.config.pricing_names :
        pricing_name => merge(
          local.microservice_vars.locals.ec2[pricing_name],
          {
            os           = local.config.os
            os_version   = local.config.os_version
            architecture = local.config.architecture
          },
          {
            instance_type = local.microservice_vars.locals.ec2_instances[local.config.ec2_instance_key].name
          }
        )
        if local.config.deployment_type == "ec2"
      }
      fargate = merge(
        local.microservice_vars.locals.fargate,
        {
          os = local.config.os
          # os_version   = local.config.os_version
          architecture = local.config.architecture
        },
        {
          capacity_provider = { for pricing_name in local.config.pricing_names :
            pricing_name => local.microservice_vars.locals.fargate.capacity_provider[pricing_name]
            if local.config.deployment_type == "fargate"
          }
      })
      }
    )
  }

  dynamodb_tables = [for table in local.config_override.dynamodb : {
    name                 = table.name
    primary_key_name     = table.primaryKeyName
    primary_key_type     = table.primaryKeyType
    sort_key_name        = table.sortKeyName
    sort_key_type        = table.sortKeyType
    predictable_workload = false
  }]

  bucket_picture = {
    name          = local.config_override.buckets.picture.name
    force_destroy = false
    versioning    = true
  }

  tags = merge(
    local.convention_tmp_vars.locals.tags,
    local.account_vars.locals.tags,
    local.config.tags,
  )
}
