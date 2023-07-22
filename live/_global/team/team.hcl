locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account_override.hcl"))

  repositories_aws_account_region = local.account_vars.locals.repositories_aws_account_region
  repositories_aws_account_name   = local.account_vars.locals.repositories_aws_account_name
  repositories_aws_account_id     = local.account_vars.locals.repositories_aws_account_id

  name = "vistimi-scraper"
  aws = {
    admins    = []
    devs      = [{ name = "olivier" }]
    machines  = [{ name = "live" }]
    resources = [{ name = "repositories", mutable = false }]
  }
  github = {
    repository_names = ["dresspeng/infrastructure-modules", "dresspeng/infrastructure-live", "dresspeng/scraper-backend", "dresspeng/scraper-frontend"]
  }

  tags = {}
}
