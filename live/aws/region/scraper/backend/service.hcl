locals {
  service_tmp_vars = read_terragrunt_config("${get_terragrunt_dir()}/service_override.hcl")
  branch_name      = local.service_tmp_vars.locals.branch_name

  cidr_ipv4          = "1.0.0.0/16"
  vpc_tier           = "public"
  project_name       = "scraper"
  service_name       = "backend"
  git_host_name      = "github.com"
  organization_name  = "KookaS"
  repository_name    = "scraper-backend"
  image_tag          = "latest"
  use_fargate        = false
  pricing_names      = ["on-demand"]
  os                 = "linux"
  os_version         = "2023"
  architecture       = "x64"
  ec2_instance_key   = "t3_small"
  task_min_count     = 0
  task_desired_count = 1
  task_max_count     = 1

  tags = {
    "Git Microservice" = "${local.git_host_name}/${local.organization_name}/${local.repository_name}@${local.branch_name}"
    "Project"          = local.project_name
    "Service"          = local.service_name
  }
}
