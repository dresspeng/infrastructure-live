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

  # {
  #   sid       = "EcrWrite"
  #   actions   = flatten([for perm in ["write", "permission_management", "tagging"] : local.action_vars.locals["ecr_${perm}"]])
  #   effect    = "Allow"
  #   resources = ["*"]
  # },

  level_statements = [
    {
      sid       = "S3Read"
      actions   = ["s3:ListBucket", "s3:ListAllMyBuckets"]
      effect    = "Allow"
      resources = ["*"]
    },
    {
      sid       = "EcrAuth"
      actions   = ["ecr:GetAuthorizationToken"]
      effect    = "Allow"
      resources = ["*"]
    },
    {
      sid       = "EcrPublicAuth"
      actions   = ["ecr-public:GetAuthorizationToken"]
      effect    = "Allow"
      resources = ["*"]
    },
    {
      sid = "EcrReadExternal"
      actions = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
      ]
      effect    = "Allow"
      resources = ["*"]
      conditions = [
        {
          test     = "StringNotEquals"
          variable = "aws:PrincipalAccount"
          values   = [local.account_id]
        }
      ]
    },
    {
      sid = "EcrPublicReadExternal"
      actions = [
        "ecr-public:GetAuthorizationToken",
        "ecr-public:BatchCheckLayerAvailability",
      ]
      effect    = "Allow"
      resources = ["*"]
      conditions = [
        {
          test     = "StringNotEquals"
          variable = "aws:PrincipalAccount"
          values   = [local.account_id]
        }
      ]
    },
  ]

  levels = [{ key = "organization", value = "vistimi" }, { key = "team", value = "scraper" }]

  aws = {
    levels = local.levels

    groups = {
      admin = {
        force_destroy = true
        pw_length     = 20
        users = [{
          name = "perm"
          statements = [
            {
              sid       = "All"
              actions   = ["iam:*"]
              effect    = "Allow"
              resources = ["*"]
            },
            {
              sid       = "DynamodbBackend"
              actions   = ["dynamodb:*"]
              effect    = "Allow"
              resources = ["arn:aws:dynamodb:*:${local.account_id}:table/vi-tf-locks"]
            },
            {
              sid       = "BucketBackend"
              actions   = ["s3:*"]
              effect    = "Allow"
              resources = ["arn:aws:s3:::vi-tf-state"]
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
          name       = "olivier"
          statements = []
        }]
        statements = []
      }
      machine = {
        force_destroy            = true
        pw_length                = 20
        project_names            = ["scraper"]
        github_store_environment = true
        users = [
          {
            name = "live"
          },
          {
            name = "test"
          }
        ]
        statements = [
          {
            sid = "EcrReadExternal"
            actions = [
              "ecr:GetAuthorizationToken",
              "ecr:BatchCheckLayerAvailability",
              "ecr:GetDownloadUrlForLayer",
              "ecr:BatchGetImage",
            ]
            effect    = "Allow"
            resources = ["arn:aws:ecr:*:${local.account_id}:repository/infrastructure-live-*", "arn:aws:ecr:*:${local.account_id}:repository/infrastructure-modules-*"]
          },
          {
            sid = "EcrPublicReadExternal"
            actions = [
              "ecr-public:GetAuthorizationToken",
              "ecr-public:BatchCheckLayerAvailability",
            ]
            effect    = "Allow"
            resources = ["*"]
          },
        ]
      }
      base = {
        force_destroy            = true
        pw_length                = 20
        github_store_environment = true
        users = [
          {
            name = "docker"
            statements = [
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
