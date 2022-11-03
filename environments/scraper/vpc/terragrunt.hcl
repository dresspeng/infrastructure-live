include "root" {
  path = find_in_parent_folders()
}

dependencies {
  paths = ["../../backend"]
}

terraform {
  source = "${get_terragrunt_dir()}/../../../modules//vpc"
}

inputs = {
  region  = var.region
  project_name = "scraper"
  environment_name = var.environment_name
  common_tags = merge(var.common_tags, {Project: "Scraper"})
  vpc_cidr_ipv4 = var.vpc_cidr_ipv4
}