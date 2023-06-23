include {
  path = find_in_parent_folders()
}

locals {
  convention_vars   = read_terragrunt_config(find_in_parent_folders("convention_override.hcl"))
  account_vars      = read_terragrunt_config(find_in_parent_folders("account_override.hcl"))
  microservice_vars = read_terragrunt_config(find_in_parent_folders("microservice.hcl"))
  project_vars      = read_terragrunt_config(find_in_parent_folders("project.hcl"))
  service_vars      = read_terragrunt_config("${get_terragrunt_dir()}/service_override.hcl")

  organization_name         = local.convention_vars.locals.organization_name
  environment_name          = local.convention_vars.locals.environment_name
  modules_git_name          = local.convention_vars.locals.modules_git_name
  modules_organization_name = local.convention_vars.locals.modules_organization_name
  modules_repository_name   = local.convention_vars.locals.modules_repository_name
  modules_branch_name       = local.convention_vars.locals.modules_branch_name

  account_region_names = local.account_vars.locals.account_region_names
  account_name         = local.account_vars.locals.account_name
  account_id           = local.account_vars.locals.account_id

  project_name = local.project_vars.locals.project_name

  common_name = local.service_vars.locals.common_name
  # organization_name = local.service_vars.locals.organization_name
  repository_name = local.service_vars.locals.repository_name
  branch_name     = local.service_vars.locals.branch_name

  config_vars = yamldecode(file("${get_terragrunt_dir()}/config_override.yml"))

  spot             = local.microservice_vars.locals.spot
  on_demand        = local.microservice_vars.locals.on_demand
  ec2_microservice = local.microservice_vars.locals.ec2_x64_linux_complete
  ec2_user_data = {
    "${local.spot}" = {
      user_data = <<EOT
            #!/bin/bash
            cat <<'EOF' >> /etc/ecs/ecs.config
                ECS_CLUSTER=${local.common_name}
            EOF
        EOT
    }
    "${local.on_demand}" = {
      user_data = <<EOT
            #!/bin/bash
            cat <<'EOF' >> /etc/ecs/ecs.config
                ECS_CLUSTER=${local.common_name}
            EOF
        EOT
    }
  }

  ec2 = {
    # local.spot = merge(local.ec2_microservice[local.spot], {user_data = format("%s\n%s", local.ec2_microservice[local.spot].user_data, local.ec2_user_data[local.spot])})
    "${local.on_demand}" = merge(local.ec2_microservice[local.on_demand], {
      user_data = format("%s\n%s", local.ec2_microservice[local.on_demand].user_data, local.ec2_user_data[local.on_demand].user_data)
    })
  }
  # fargate = local.microservice_vars.locals.fargate_x64_linux_complete



  # ecs_default = local.microservice_vars.locals.ecs_fargate
  ecs_default = local.microservice_vars.locals.ecs_ec2

  env_key                 = "${local.branch_name}.env"
  task_definition_default = local.microservice_vars.locals.task_definition_ec2
  bucket_env = {
    name      = "${local.common_name}-env"
    file_key  = local.env_key
    file_path = "override.env"
  }
}

terraform {
  source = "git::git@${local.modules_git_name}:${local.modules_organization_name}/${local.modules_repository_name}.git//module/aws/microservice/${local.repository_name}?ref=${local.modules_branch_name}"
}

inputs = {
  common_name = local.common_name
  common_tags = merge(
    local.convention_vars.locals.common_tags,
    local.account_vars.locals.common_tags,
    local.project_vars.locals.common_tags,
    local.service_vars.locals.common_tags,
  )

  vpc = {
    name       = local.common_name
    cidr_ipv4  = "1.0.0.0/16"
    enable_nat = false
    tier       = "Public"
  }

  ecs = merge(local.ecs_default, {
    traffic = {
      listener_port             = 80
      listener_protocol         = "http"
      listener_protocol_version = "http"
      target_port               = local.config_vars.port
      target_protocol           = "http"
      target_protocol_version   = "http"
      health_check_path         = local.config_vars.healthCheckPath
    }
    },
    {
      task_definition = merge(local.task_definition_default, {
        env_bucket_name      = "${local.common_name}-env",
        env_file_name        = local.env_key
        repository_name      = lower("${local.organization_name}-${local.repository_name}-${local.branch_name}")
        repository_image_tag = "latest"
      })
    }
  )

  dynamodb_tables = [for table in local.config_vars.dynamodb : {
    name                 = table.name
    primary_key_name     = table.primaryKeyName
    primary_key_type     = table.primaryKeyType
    sort_key_name        = table.sortKeyName
    sort_key_type        = table.sortKeyType
    predictable_workload = false
  }]

  bucket_picture = {
    name          = "${local.common_name}-${local.config_vars.buckets.picture.name}"
    force_destroy = false
    versioning    = true
  }
}
