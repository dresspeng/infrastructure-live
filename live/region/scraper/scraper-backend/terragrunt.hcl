include {
  path = find_in_parent_folders()
}

locals {
  account_vars     = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl"))

  # global
  aws_account_name          = local.account_vars.locals.aws_account_name
  aws_account_id            = local.account_vars.locals.aws_account_id
  github_organization       = local.account_vars.locals.github_organization
  github_modules_repository = local.account_vars.locals.github_modules_repository
  github_modules_branch     = local.account_vars.locals.github_modules_branch
  aws_region                = local.region_vars.locals.aws_region
  project_name              = local.environment_vars.locals.project_name
  environment_name          = local.environment_vars.locals.environment_name
  service_name              = "backend"
  common_name               = "${local.project_name}-${local.environment_name}-${local.service_name}"

  # end
  vpc_tier              = "Public"
  protect_from_scale_in = false
  listener_port         = 80
  listener_protocol     = "HTTP"
  target_port           = 8080
  target_protocol       = "HTTP"
  user_data             = "#!/bin/bash\necho ECS_CLUSTER=${local.common_name} >> /etc/ecs/ecs.config;"

  ecs_execution_role_name               = "${local.common_name}-ecs-execution"
  ecs_task_container_role_name          = "${local.common_name}-ecs-task-container"
  ecs_task_container_s3_env_policy_name = "${local.common_name}-ecs-task-container-s3-env"
  ecs_task_definition_image_tag         = "latest"
  env_file_name                         = "production.env"
  bucket_env_name                       = "${local.common_name}-env"


  github_repository = "scraper-backend"
  github_branch     = "production"
  health_check_path = "/"
}

dependency "vpc" {
  config_path = "../vpc"
}

terraform {
  source = "git::git@github.com:${local.github_organization}/${local.github_modules_repository}.git//modules/services/${local.github_repository}?ref=${local.github_modules_branch}"
}

inputs = {
  # global
  account_region         = local.aws_region
  account_id             = local.aws_account_id
  account_name           = local.aws_account_name
  vpc_id                 = dependency.vpc.outputs.vpc_id
  vpc_security_group_ids = [dependency.vpc.outputs.default_security_group_id]
  common_name            = local.common_name
  common_tags = {
    Account     = local.aws_account_name
    Region      = local.aws_region
    Project     = local.project_name
    Service     = local.service_name
    Environment = local.environment_name
  }
  force_destroy = false

  # backend
  ecs_execution_role_name                = local.ecs_execution_role_name
  ecs_task_container_role_name           = local.ecs_task_container_role_name
  ecs_task_definition_image_tag          = local.ecs_task_definition_image_tag
  ecs_task_container_s3_env_policy_name  = local.ecs_task_container_s3_env_policy_name
  ecs_logs_retention_in_days             = local.environment_vars.locals.backend_ecs_logs_retention_in_days
  listener_port                          = local.listener_port
  listener_protocol                      = local.listener_protocol
  target_port                            = local.target_port
  target_protocol                        = local.target_protocol
  target_capacity_cpu                    = local.environment_vars.locals.backend_target_capacity_cpu
  capacity_provider_base                 = local.environment_vars.locals.backend_capacity_provider_base
  capacity_provider_weight_on_demand     = local.environment_vars.locals.backend_capacity_provider_weight_on_demand
  capacity_provider_weight_spot          = local.environment_vars.locals.backend_capacity_provider_weight_spot
  user_data                              = local.user_data
  protect_from_scale_in                  = local.protect_from_scale_in
  vpc_tier                               = local.vpc_tier
  instance_type_on_demand                = local.environment_vars.locals.backend_instance_type_on_demand
  min_size_on_demand                     = local.environment_vars.locals.backend_min_size_on_demand
  max_size_on_demand                     = local.environment_vars.locals.backend_max_size_on_demand
  desired_capacity_on_demand             = local.environment_vars.locals.backend_desired_capacity_on_demand
  minimum_scaling_step_size_on_demand    = local.environment_vars.locals.backend_minimum_scaling_step_size_on_demand
  maximum_scaling_step_size_on_demand    = local.environment_vars.locals.backend_maximum_scaling_step_size_on_demand
  instance_type_spot                     = local.environment_vars.locals.backend_instance_type_spot
  min_size_spot                          = local.environment_vars.locals.backend_min_size_spot
  max_size_spot                          = local.environment_vars.locals.backend_max_size_spot
  desired_capacity_spot                  = local.environment_vars.locals.backend_desired_capacity_spot
  minimum_scaling_step_size_spot         = local.environment_vars.locals.backend_minimum_scaling_step_size_spot
  maximum_scaling_step_size_spot         = local.environment_vars.locals.backend_maximum_scaling_step_size_spot
  ecs_task_definition_memory             = local.environment_vars.locals.backend_ecs_task_definition_memory
  ecs_task_definition_memory_reservation = local.environment_vars.locals.backend_ecs_task_definition_memory_reservation
  ecs_task_definition_cpu                = local.environment_vars.locals.backend_ecs_task_definition_cpu
  ecs_task_desired_count                 = local.environment_vars.locals.backend_ecs_task_desired_count
  env_file_name                          = local.env_file_name
  bucket_env_name                        = local.bucket_env_name
  port_mapping = [
    {
      hostPort      = local.target_port
      protocol      = "tcp"
      containerPort = local.target_port
    },
    {
      hostPort      = 27017
      protocol      = "tcp"
      containerPort = 27017
    }
  ]

  # github
  repository_image_keep_count = 1
  github_organization         = local.github_organization
  github_repository           = local.github_repository
  github_branch               = local.github_branch
  health_check_path           = local.health_check_path

  # mongodb
  ami_id         = local.environment_vars.locals.mongodb_ami_id
  instance_type  = local.environment_vars.locals.mongodb_instance_type
  user_data_path = "mongodb.sh"
  user_data_args = {
    HOME            = "/home/ec2-user"
    UID             = "1000"
    mongodb_version = local.environment_vars.locals.mongodb_version
  }

  aws_access_key = local.account_vars.locals.aws_access_key
  aws_secret_key = local.account_vars.locals.aws_secret_key
}
