locals {
  cidr_ipv4          = "2.0.0.0/16"
  vpc_tier           = "public"
  project_name       = "scraper"
  service_name       = "frontend"
  git_host_name      = "github.com"
  organization_name  = "KookaS"
  repository_name    = "scraper-frontend"
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
}
