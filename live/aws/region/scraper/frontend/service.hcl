locals {
  account_vars     = read_terragrunt_config(find_in_parent_folders("account_override.hcl"))
  service_tmp_vars = read_terragrunt_config("${get_terragrunt_dir()}/service_override.hcl")

  branch_name = local.service_tmp_vars.locals.branch_name

  vpc = {
    id   = "vpc-0d5c1d5379f616e2f"
    tier = "public"
  }
  project_name       = "scraper"
  service_name       = "frontend"
  git_host_name      = "github.com"
  organization_name  = "dresspeng"
  repository_name    = join("-", [local.project_name, local.service_name])
  pricing_names      = ["on-demand", "spot"]
  os                 = "linux"
  os_version         = "2023"
  architecture       = "x86_64"
  deployment_type    = "ec2"
  ec2_instance_key   = "t3_small"
  task_min_count     = 0
  task_desired_count = 1
  task_max_count     = 1
  iam = {
    scope        = "accounts"
    requires_mfa = false
  }
  ecs = {
    traffics = [
      {
        listener = {
          protocol = "http"
        },
        target = {
          protocol = "http"
        }
      }
    ]
    task_definition = {
      docker = {
        registry = {
          ecr = {
            privacy = "private"
          }
        }
        repository = {
          name = join("-", [local.repository_name, local.branch_name])
        }
        image = {
          tag = "latest"
        }
      }
      readonly_root_filesystem = false
    }
  }

  bucket_env = {
    name          = "env"
    file_key      = "${local.branch_name}.env"
    force_destroy = false
    versioning    = true
  }

  tags = {
    "Git Microservice" = "${local.git_host_name}/${local.organization_name}/${local.repository_name}@${local.branch_name}"
    "Project"          = local.project_name
    "Service"          = local.service_name
  }
}
