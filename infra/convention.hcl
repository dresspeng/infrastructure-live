locals {
  environment         = get_env("BRANCH_REF")
  account_region_name = get_env("AWS_DEFAULT_REGION")

  name = lower("${get_env("COMPANY_REF")}-${get_env("REPO_REF")}-${local.environment}")

  tags = {}
}
