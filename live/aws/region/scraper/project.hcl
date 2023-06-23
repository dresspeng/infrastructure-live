locals {
  project_name = "scraper"
  common_tags = {
    "Project" = local.project_name
  }

  # vpc
  vpc_cidr_ipv4 = "10.0.0.0/16"
  enable_nat    = false
}
