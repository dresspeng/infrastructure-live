locals {
  account_vars     = read_terragrunt_config(find_in_parent_folders("account_override.hcl"))
  service_tmp_vars = read_terragrunt_config("${get_terragrunt_dir()}/service_override.hcl")

  repositories_aws_account_region = local.account_vars.locals.repositories_aws_account_region
  repositories_aws_account_name   = local.account_vars.locals.repositories_aws_account_name
  repositories_aws_account_id     = local.account_vars.locals.repositories_aws_account_id

  branch_name = local.service_tmp_vars.locals.branch_name

  cidr_ipv4         = "1.0.0.0/16"
  vpc_tier          = "public"
  project_name      = "scraper"
  service_name      = "backend"
  git_host_name     = "github.com"
  organization_name = "dresspeng"
  repository_name   = "${local.project_name}-${local.service_name}"
  repository = {
    visibility = "private"
    name       = "${local.repository_name}-${local.branch_name}"
    image_tag  = "latest"
    account_id = local.repositories_aws_account_id
    region     = local.repositories_aws_account_region
  }
  pricing_names      = ["on-demand"]
  os                 = "linux"
  os_version         = "2023"
  architecture       = "x64"
  deployment_type    = "ec2"
  ec2_instance_key   = "t3_small"
  task_min_count     = 0
  task_desired_count = 1
  task_max_count     = 1
  iam = {
    scope = "accounts"
  }

  tags = {
    "Git Microservice" = "${local.git_host_name}/${local.organization_name}/${local.repository_name}@${local.branch_name}"
    "Project"          = local.project_name
    "Service"          = local.service_name
  }
}
