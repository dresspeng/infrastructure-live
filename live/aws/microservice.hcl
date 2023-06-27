locals {
  # const
  ecs_reserved_memory = 100
  use_bridge          = true

  # purchasing options
  pricing_name_spot      = "spot"
  pricing_name_on_demand = "on-demand"

  # ec2 const
  ec2_instances = {
    t3_small = {
      name           = "t3.small"
      cpu            = 2048
      memory         = 2048
      memory_allowed = 1801 # TODO: double check under infra of cluster + ECSReservedMemory
      architecture   = "x64"
    }
    t3_medium = {
      name           = "t3.medium"
      cpu            = 2048
      memory         = 4096
      memory_allowed = 3828 # TODO: double check under infra of cluster + ECSReservedMemory
      architecture   = "x64"
    }
  }

  ec2_amis = {
    linux_2 = {
      x64   = { ami_ssm_architecture = "amazon-linux-2" }
      arm64 = { ami_ssm_architecture = "amazon-linux-2-arm64" }
      gpu   = { ami_ssm_architecture = "amazon-linux-2-gpu" }
      inf   = { ami_ssm_architecture = "amazon-linux-2-inf" }
    }
    linux_2023 = {
      x64   = { ami_ssm_architecture = "amazon-linux-2" }
      arm64 = { ami_ssm_architecture = "amazon-linux-2-arm64" }
      # gpu   = { ami_ssm_architecture = "amazon-linux-2-gpu" }
      inf = { ami_ssm_architecture = "amazon-linux-2-inf" }
    }
  }

  # fargate const
  fargate_instances = {
    set_1 = {
      cpu    = 512
      memory = 1024
    }
  }

  fargate_amis = {
    linux = {
      x64 = {
        os           = "LINUX"
        architecture = "X86_64"
      }
    }
  }

  # EC2
  ec2_asg = {
    instance_refresh = {
      strategy = "Rolling"
      preferences = {
        checkpoint_delay       = 600
        checkpoint_percentages = [35, 70, 100]
        instance_warmup        = 300
        min_healthy_percentage = 80
      }
      triggers = ["tag"]
    }
  }
  ec2_capacity_provider = {
    base                        = null # no preferred instance amount
    weight_percent              = 50   # 50% chance
    target_capacity_cpu_percent = 70
    maximum_scaling_step_size   = 1
    minimum_scaling_step_size   = 1
  }
  ec2 = {
    "${local.pricing_name_spot}" = {
      user_data         = <<EOT
          #!/bin/bash
          cat <<'EOF' >> /etc/ecs/ecs.config
              ECS_LOGLEVEL=debug
              ${local.use_bridge ? "ECS_ENABLE_TASK_IAM_ROLE=true" : "ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true"}
              ECS_RESERVED_MEMORY=${local.ecs_reserved_memory}
              ECS_ENABLE_SPOT_INSTANCE_DRAINING=true
          EOF
        EOT
      key_name          = null
      use_spot          = true
      asg               = local.ec2_asg
      capacity_provider = local.ec2_capacity_provider
    }
    "${local.pricing_name_on_demand}" = {
      user_data         = <<EOT
          #!/bin/bash
          cat <<'EOF' >> /etc/ecs/ecs.config
              ECS_LOGLEVEL=debug
              ${local.use_bridge ? "ECS_ENABLE_TASK_IAM_ROLE=true" : "ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true"}
              ECS_RESERVED_MEMORY=${local.ecs_reserved_memory}
          EOF
        EOT
      key_name          = null
      use_spot          = false
      asg               = local.ec2_asg
      capacity_provider = local.ec2_capacity_provider
    }
  }

  # FARGATE
  fargate = {
    capacity_provider = {
      "${local.pricing_name_spot}" = {
        key            = "FARGATE_SPOT"
        base           = null # no preferred instance amount
        weight_percent = 50   # 50% chance        
      }
      "${local.pricing_name_on_demand}" = {
        key            = "FARGATE"
        base           = null # no preferred instance amount
        weight_percent = 50   # 50% chance        
      }
    }
  }

  # ECS
  ecs = {
    log = {
      retention_days = 30
      prefix         = "aws/ecs"
    }
    task_definition = {}
    service = {
      deployment_minimum_healthy_percent = 66
    }
  }
}
