# include "root" {
#   path = find_in_parent_folders()
# }

# dependencies {
#   paths = ["../vpc"]
# }

# terraform {
#   source = "${get_terragrunt_dir()}/../../../modules/services//scraper-backend"
# }

# inputs{
#   common_tags = merge(var.common_tags, {Project: "Scraper"})
# }