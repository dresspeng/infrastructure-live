include {
  path = find_in_parent_folders()
}

locals {
  convention_vars   = read_terragrunt_config(find_in_parent_folders("convention_override.hcl"))
  account_vars      = read_terragrunt_config(find_in_parent_folders("account_override.hcl"))
  microservice_vars = read_terragrunt_config(find_in_parent_folders("microservice.hcl"))
  service_vars      = read_terragrunt_config("${get_terragrunt_dir()}/service.hcl")
  service_tmp_vars  = read_terragrunt_config("${get_terragrunt_dir()}/service_override.hcl")

  override_extension_name   = local.convention_vars.locals.override_extension_name
  modules_git_host_name     = local.convention_vars.locals.modules_git_host_name
  modules_organization_name = local.convention_vars.locals.modules_organization_name
  modules_repository_name   = local.convention_vars.locals.modules_repository_name
  modules_branch_name       = local.convention_vars.locals.modules_branch_name

  domain_name         = local.account_vars.locals.domain_name
  account_region_name = local.account_vars.locals.account_region_name
  account_name        = local.account_vars.locals.account_name
  account_id          = local.account_vars.locals.account_id

  cidr_ipv4          = local.service_vars.locals.cidr_ipv4
  vpc_tier           = local.service_vars.locals.vpc_tier
  project_name       = local.service_vars.locals.project_name
  service_name       = local.service_vars.locals.service_name
  git_host_name      = local.service_vars.locals.git_host_name
  organization_name  = local.service_vars.locals.organization_name
  repository_name    = local.service_vars.locals.repository_name
  image_tag          = local.service_vars.locals.image_tag
  deployment_type    = local.service_vars.locals.deployment_type
  pricing_names      = local.service_vars.locals.pricing_names
  os                 = local.service_vars.locals.os
  os_version         = local.service_vars.locals.os_version
  architecture       = local.service_vars.locals.architecture
  task_min_count     = local.service_vars.locals.task_min_count
  task_desired_count = local.service_vars.locals.task_desired_count
  task_max_count     = local.service_vars.locals.task_max_count

  branch_name = local.service_tmp_vars.locals.branch_name

  config_vars = yamldecode(file("${get_terragrunt_dir()}/config_override.yml"))

  name = lower("${local.organization_name}-${local.repository_name}-${local.branch_name}")

  pricing_name_spot      = local.microservice_vars.locals.pricing_name_spot
  pricing_name_on_demand = local.microservice_vars.locals.pricing_name_on_demand
  ec2_user_data = {
    "${local.pricing_name_spot}" = {
      user_data = <<EOT
            #!/bin/bash
            cat <<'EOF' >> /etc/ecs/ecs.config
                ECS_CLUSTER=${local.name}
            EOF
        EOT
    }
    "${local.pricing_name_on_demand}" = {
      user_data = <<EOT
            #!/bin/bash
            cat <<'EOF' >> /etc/ecs/ecs.config
                ECS_CLUSTER=${local.name}
            EOF
        EOT
    }
  }
  ec2_microservice = local.microservice_vars.locals.ec2
  ec2 = { for pricing_name in local.pricing_names :
    pricing_name => merge(
      local.ec2_microservice[pricing_name],
      {
        os           = local.service_vars.locals.os
        os_version   = local.service_vars.locals.os_version
        architecture = local.service_vars.locals.architecture
      },
      {
        user_data     = format("%s\n%s", local.ec2_microservice[pricing_name].user_data, local.ec2_user_data[pricing_name].user_data)
        instance_type = local.microservice_vars.locals.ec2_instances[local.service_vars.locals.ec2_instance_key].name
      }
    )
    if local.deployment_type == "ec2"
  }


  fargate_microservice = local.microservice_vars.locals.fargate
  fargate = merge(
    local.fargate_microservice,
    {
      os = local.service_vars.locals.os
      # os_version   = local.service_vars.locals.os_version
      architecture = local.service_vars.locals.architecture
    },
    {
      capacity_provider = { for pricing_name in local.pricing_names :
        pricing_name => local.fargate_microservice.capacity_provider[pricing_name]
        if local.deployment_type == "fargate"
      }
  })

  task_definition = local.use_fargate ? {
    cpu                = local.microservice_vars.locals.fargate_instances[local.service_vars.locals.fargate_instance_key].cpu
    memory             = local.microservice_vars.locals.fargate_instances[local.service_vars.locals.fargate_instance_key].memory
    memory_reservation = null
    } : {
    cpu                = local.microservice_vars.locals.ec2_instances[local.service_vars.locals.ec2_instance_key].cpu
    memory             = local.microservice_vars.locals.ec2_instances[local.service_vars.locals.ec2_instance_key].memory_allowed - local.microservice_vars.locals.ecs_reserved_memory
    memory_reservation = local.microservice_vars.locals.ec2_instances[local.service_vars.locals.ec2_instance_key].memory_allowed - local.microservice_vars.locals.ecs_reserved_memory
  }

  env_key         = "${local.branch_name}.env"
  env_local_path  = "${local.override_extension_name}.env"
  env_bucket_name = "${local.name}-env"

}

terraform {
  before_hook "env" {
    commands = ["init"]
    execute = [
      "/bin/bash",
      "-c",
      "echo COMMON_NAME=${local.name} >> ${get_terragrunt_dir()}/${local.env_local_path}"
    ]
  }

  source = "git::git@${local.modules_git_host_name}:${local.modules_organization_name}/${local.modules_repository_name}.git//module/aws/microservice/${local.repository_name}?ref=${local.modules_branch_name}"
}

inputs = {
  common_name = local.name
  common_tags = merge(
    local.convention_vars.locals.tags,
    local.account_vars.locals.tags,
    local.service_vars.locals.tags,
  )

  microservice = {
    vpc = {
      name      = local.name
      cidr_ipv4 = local.cidr_ipv4
      tier      = local.vpc_tier
    }

    iam = {
      scope = "accounts"
    }

    route53 = {
      zones = [
        {
          name = local.domain_name
        }
      ]
      record = {
        prefixes       = ["www"]
        subdomain_name = format("%s%s", local.branch_name == "master" ? "" : "${local.branch_name}.", local.repository_name)
      }
    }

    bucket_env = {
      name          = local.env_bucket_name
      file_key      = local.env_key
      file_path     = "${path_relative_to_include()}/${local.env_local_path}"
      force_destroy = false
      versioning    = true
    }

    ecs = merge(local.microservice_vars.locals.ecs, {
      traffic = {
        listeners = [
          {
            port             = 80
            protocol         = "http"
            protocol_version = "http"
          },
          {
            port             = 443
            protocol         = "https"
            protocol_version = "http"
          }
        ]
        target = {
          port              = local.config_vars.port
          protocol          = "http"
          protocol_version  = "http"
          health_check_path = local.config_vars.healthCheckPath
        }
      }
      service = merge(
        local.microservice_vars.locals.ecs.service,
        {
          deployment_type    = local.use_fargate
          task_min_count     = local.task_min_count
          task_desired_count = local.task_desired_count
          task_max_count     = local.task_max_count
          deployment_circuit_breaker = local.use_fargate ? null : {
            enable   = true
            rollback = true
          }
        }
      )
      task_definition = merge(
        local.microservice_vars.locals.ecs.task_definition,
        local.task_definition,
        {
          env_bucket_name      = local.env_bucket_name,
          env_file_name        = local.env_key
          repository_name      = local.name
          repository_image_tag = local.image_tag
        }
      )
      ec2     = local.ec2
      fargate = local.fargate
      }
    )
  }

  dynamodb_tables = [for table in local.config_vars.dynamodb : {
    name                 = table.name
    primary_key_name     = table.primaryKeyName
    primary_key_type     = table.primaryKeyType
    sort_key_name        = table.sortKeyName
    sort_key_type        = table.sortKeyType
    predictable_workload = false
  }]

  bucket_picture = {
    name          = "${local.name}-${local.config_vars.buckets.picture.name}"
    force_destroy = false
    versioning    = true
  }
}
