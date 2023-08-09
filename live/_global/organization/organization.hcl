# Create backup before doing any changes
# plan before changes

locals {
  action_vars  = read_terragrunt_config("${get_repo_root()}/live/aws/_global/iam/actions.hcl")
  account_vars = read_terragrunt_config(find_in_parent_folders("account_override.hcl"))

  domain_name         = local.account_vars.locals.domain_name
  domain_suffix       = local.account_vars.locals.domain_suffix
  account_region_name = local.account_vars.locals.account_region_name
  account_name        = local.account_vars.locals.account_name
  account_id          = local.account_vars.locals.account_id

  backend_prefix = "dresspeng"
  projects = {
    scraper = ["scraper-backend", "scraper-frontend"]
  }

  level_statements = [
    {
      sid       = "IamUser"
      actions   = ["iam:ListMFADevices", "iam:CreateVirtualMFADevice", "iam:DeactivateMFADevice", "iam:ListAccessKeys"]
      effect    = "Allow"
      resources = ["*"]
    },
    {
      sid       = "S3Read"
      actions   = ["s3:DescribeJob", "s3:Get*", "s3:List*"] // s3:ListBucket
      effect    = "Allow"
      resources = ["*"]
    },
  ]

  levels = [{ key = "organization", value = "dress" }, { key = "team", value = "scraper" }]

  aws = {
    levels = local.levels

    groups = {
      admin = {
        force_destroy = true
        pw_length     = 20
        users = [{
          name = "root"
          statements = [
            {
              sid       = "All"
              actions   = ["*"]
              effect    = "Allow"
              resources = ["*"]
            },
          ]
        }]
      }
      dev = {
        force_destroy            = true
        pw_length                = 20
        project_names            = ["scraper"]
        github_store_environment = true
        users = [{
          name = "olivier"
          statements = [
            {
              sid = "EcrFull"
              actions = [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
              ]
              effect    = "Allow"
              resources = ["*"]
            },
            {
              sid = "EcrPublicFull"
              actions = [
                "ecr-public:GetAuthorizationToken",
                "ecr-public:BatchCheckLayerAvailability",
              ]
              effect    = "Allow"
              resources = ["*"]
            },
          ]
        }]
        statements = [
          {
            sid       = "S3Backend"
            actions   = ["s3:*"]
            effect    = "Allow"
            resources = [for repository_name in local.projects.scraper : "arn:aws:s3:::${local.backend_prefix}-${repository_name}-olivier-*"]
          },
        ]
      }
      machine = {
        force_destroy            = true
        pw_length                = 20
        project_names            = ["scraper"]
        github_store_environment = true
        users = [{
          name = "live"
          statements = [
            {
              sid = "EcrFull"
              actions = [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
              ]
              effect    = "Allow"
              resources = ["*"]
            },
            {
              sid = "EcrPublicFull"
              actions = [
                "ecr-public:GetAuthorizationToken",
                "ecr-public:BatchCheckLayerAvailability",
              ]
              effect    = "Allow"
              resources = ["*"]
            },
            {
              sid       = "S3Backend"
              actions   = ["s3:*"]
              effect    = "Allow"
              resources = [for repository_name in local.projects.scraper : "arn:aws:s3:::${local.backend_prefix}-${repository_name}-live-*"]
            },
            {
              sid       = "DynamodbBackend"
              actions   = ["dynamodb:*"]
              effect    = "Allow"
              resources = [for repository_name in local.projects.scraper : "arn:aws:dynamodb:${local.account_region_name}:${local.account_id}:table/${local.backend_prefix}-${repository_name}-live-*"]
            },
          ]
        }]
      }
      base = {
        force_destroy            = true
        pw_length                = 20
        github_store_environment = true
        users = [
          {
            name = "docker"
            statements = [
              # {
              #   sid       = "EcrWrite"
              #   actions   = flatten([for perm in ["write", "permission_management", "tagging"] : local.action_vars.locals["ecr_${perm}"]])
              #   effect    = "Allow"
              #   resources = ["*"]
              # },
              # {
              #   sid       = "EcrPublicWrite"
              #   actions   = flatten([for perm in ["write", "permission_management", "tagging"] : local.action_vars.locals["ecr_public_${perm}"]])
              #   effect    = "Allow"
              #   resources = ["*"]
              # },
              {
                sid       = "EcrFull"
                actions   = ["ecr:*"]
                effect    = "Allow"
                resources = ["*"]
              },
              {
                sid       = "EcrPublicFull"
                actions   = ["ecr-public:*"]
                effect    = "Allow"
                resources = ["*"]
              },
            ]
          }
        ]
      }
    }
    statements                = local.level_statements
    external_assume_role_arns = []

    store_secrets = true
    tags          = {}
  }

  github = {
    repositories = [
      { owner = "dresspeng", name = "infrastructure-modules" },
      { owner = "dresspeng", name = "infrastructure-live" },
      { owner = "dresspeng", name = "scraper-backend" },
      { owner = "dresspeng", name = "scraper-frontend" },
    ]
    variables = [
      { key = "ECR_ENV_NAME", value = "docker" },
    ]
  }
}
