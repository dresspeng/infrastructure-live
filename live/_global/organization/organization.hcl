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
      sid     = "Scraper"
      actions = ["ecs:*", "ec2:*", "autoscaling:*", "autoscaling-plans:*", "application-autoscaling:*", "logs:*", "cloudwatch:*", "ssm:*", "iam:*", "kms:*", "elasticloadbalancing:*"] # "iam:CreatePolicy", "kms:DescribeKey", "elasticloadbalancing:CreateLoadBalancer", "application-autoscaling:RegisterScalableTarget"
      # "cloudwatch:PutMetricStream",
      # "logs:CreateLogDelivery",
      # "logs:CreateLogStream",
      # "cloudwatch:PutMetricData",
      # "logs:UpdateLogDelivery",
      # "logs:CreateLogGroup",
      # "logs:PutLogEvents",
      # "cloudwatch:ListMetrics"
      effect    = "Allow"
      resources = ["*"]
    },
    {
      sid       = "IamUser"
      actions   = ["iam:ListMFADevices", "iam:CreateVirtualMFADevice", "iam:DeactivateMFADevice", "iam:ListAccessKeys"]
      effect    = "Allow"
      resources = ["*"]
    },
    {
      sid       = "EcrRead"
      actions   = flatten([for perm in ["read", "list"] : local.action_vars.locals["ecr_${perm}"]])
      effect    = "Allow"
      resources = ["*"]
    },
    {
      sid       = "EcrPublicRead"
      actions   = flatten([for perm in ["read", "list"] : local.action_vars.locals["ecr_public_${perm}"]])
      effect    = "Allow"
      resources = ["*"]
    },
    {
      sid       = "Route53RecordsFull"
      actions   = ["route53:ChangeResourceRecordSets", "route53:ListResourceRecordSets", "route53:GetHostedZone", "route53:GetHostedZoneCount", "route53:ListHostedZones", "route53:ListHostedZonesByName", "route53:ListHostedZonesByVPC", "route53:ListTagsForResource"]
      effect    = "Allow"
      resources = ["*"]
    },
    {
      sid       = "AcmFull"
      actions   = ["acm:*"]
      effect    = "Allow"
      resources = ["*"]
    },
    {
      sid       = "S3Read"
      actions   = ["s3:DescribeJob", "s3:Get*", "s3:List*"]
      effect    = "Allow"
      resources = ["*"]
    },
  ]

  levels = [{ key = "organization", value = "dress" }, { key = "team", value = "scraper" }]

  aws = {
    levels = local.levels

    groups = {
      dev = {
        force_destroy = true
        pw_length     = 20
        users = [{
          name = "olivier"
          statements = [
            {
              sid       = "S3Backend"
              actions   = ["s3:*"]
              effect    = "Allow"
              resources = [for repository_name in local.projects.scraper : "arn:aws:s3:::${local.backend_prefix}-${repository_name}-olivier-*"]
            },
            {
              sid       = "DynamodbBackend"
              actions   = ["dynamodb:*"]
              effect    = "Allow"
              resources = [for repository_name in local.projects.scraper : "arn:aws:dynamodb:${local.account_region_name}:${local.account_id}:table/${local.backend_prefix}-${repository_name}-olivier-*"]
            },
            {
              sid       = "S3Scraper"
              actions   = ["s3:*"]
              effect    = "Allow"
              resources = [for repository_name in local.projects.scraper : "arn:aws:s3:::${repository_name}-olivier-*"]

            },
            {
              sid       = "DynamodbScraper"
              actions   = ["dynamodb:*"]
              effect    = "Allow"
              resources = [for repository_name in local.projects.scraper : "arn:aws:dynamodb:${local.account_region_name}:${local.account_id}:table/${repository_name}-olivier-*"]
            },
          ]
        }]
      }
      machine = {
        force_destroy = true
        pw_length     = 20
        users = [{
          name = "live"
          statements = [
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
            {
              sid       = "S3Scraper"
              actions   = ["s3:*"]
              effect    = "Allow"
              resources = [for repository_name in local.projects.scraper : "arn:aws:s3:::${repository_name}-live-*"]

            },
            {
              sid       = "DynamodbScraper"
              actions   = ["dynamodb:*"]
              effect    = "Allow"
              resources = [for repository_name in local.projects.scraper : "arn:aws:dynamodb:${local.account_region_name}:${local.account_id}:table/${repository_name}-live-*"]
            },
          ]
        }]
      }
      base = {
        force_destroy = true
        pw_length     = 20
        users = [
          {
            name = "docker"
            statements = [
              {
                sid       = "EcrWrite"
                actions   = flatten([for perm in ["write", "permission_management", "tagging"] : local.action_vars.locals["ecr_${perm}"]])
                effect    = "Allow"
                resources = ["*"]
              },
              {
                sid       = "EcrPublicWrite"
                actions   = flatten([for perm in ["write", "permission_management", "tagging"] : local.action_vars.locals["ecr_public_${perm}"]])
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
    docker_action = {
      key   = "ECR_ENV_NAME"
      value = "docker"
    }
    store_environment = true
  }
}
