terraform {
  source = "${get_terragrunt_dir()}/../../modules//backend"
}

inputs = {
  backend_name = "terraform-state-backend-production"
}
