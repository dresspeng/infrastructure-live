locals {
  # global
  project_name           = "scraper"
  environment_name       = "production"
  vpc_cidr_ipv4          = "10.0.0.0/16"
  repository_image_count = 10
  enable_nat             = true

  # backend
  backend_ecs_logs_retention_in_days             = 14
  backend_target_capacity_cpu                    = 70
  backend_capacity_provider_base                 = 1
  backend_capacity_provider_weight_on_demand     = 30
  backend_capacity_provider_weight_spot          = 70
  backend_instance_type_on_demand                = "t4g.nano"
  backend_min_size_on_demand                     = 0
  backend_max_size_on_demand                     = 5
  backend_desired_capacity_on_demand             = 0
  backend_minimum_scaling_step_size_on_demand    = 1
  backend_maximum_scaling_step_size_on_demand    = 3
  backend_instance_type_spot                     = "t4g.nano"
  backend_min_size_spot                          = 0
  backend_max_size_spot                          = 10
  backend_desired_capacity_spot                  = 1
  backend_minimum_scaling_step_size_spot         = 1
  backend_maximum_scaling_step_size_spot         = 3
  backend_ecs_task_definition_memory             = 512
  backend_ecs_task_definition_memory_reservation = 500
  backend_ecs_task_definition_cpu                = 512
  backend_ecs_task_desired_count                 = 1

  # mongodb
  mongodb_instance_type = "t4g.nano"
  mongodb_ami_id        = "ami-09d3b3274b6c5d4aa"
  mongodb_version       = "6.0.1"

  # frontend
}

