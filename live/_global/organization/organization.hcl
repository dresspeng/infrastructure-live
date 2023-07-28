# Create backup before doing any changes
# plan before changes

locals {
  action_vars = read_terragrunt_config("${get_repo_root()}/live/aws/_global/iam/actions.hcl")

  level_statements = [
    # {
    #   sid       = "General"
    #   actions   = ["ecs:*", "ec2:*", "logs:*", "s3:*", "dynamodb:*", "secretsmanager:*", "route53:*", "route53domains:ListDomains"]
    #   effect    = "Allow"
    #   resources = ["*"]
    # },
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
      actions   = ["route53:ChangeResourceRecordSets", "route53:ListResourceRecordSets", "route53:GetHostedZone", "route53:GetHostedZoneCount", "route53:ListHostedZones", "route53:ListHostedZonesByName", "route53:ListHostedZonesByVPC"]
      effect    = "Allow"
      resources = ["*"]
    },
    {
      sid       = "ACM"
      actions   = flatten([for perm in ["read", "list", "write", "permission_management", "tagging"] : local.action_vars.locals["acm_${perm}"]])
      effect    = "Allow"
      resources = ["*"]
    },
  ]

  levels = [{ key = "organization", value = "dress" }, { key = "team", value = "scraper" }]

  aws = {
    levels = local.levels

    groups = {
      dev = {
        force_destroy         = true
        create_admin_role     = false
        create_poweruser_role = true
        create_readonly_role  = false
        attach_role_name      = "poweruser"
        pw_length             = 20
        users = [{
          name = "olivier"
        }]
      }
      machine = {
        force_destroy         = true
        create_admin_role     = false
        create_poweruser_role = true
        create_readonly_role  = false
        attach_role_name      = "poweruser"
        pw_length             = 20
        users = [{
          name = "live"
        }]
      }
      base = {
        force_destroy         = true
        create_admin_role     = false
        create_poweruser_role = false
        create_readonly_role  = true
        attach_role_name      = "readonly"
        pw_length             = 20
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
      value = join("-", concat([for level in local.levels : level.value], ["base", "docker"]))
    }
    store_environment = true
  }
}
