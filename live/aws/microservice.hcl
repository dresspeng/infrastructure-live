locals {
  # const
  ecs_reserved_memory = 100

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
      architecture   = "x86_64"
    }
    t3_medium = {
      name           = "t3.medium"
      cpu            = 2048
      memory         = 4096
      memory_allowed = 3828 # TODO: double check under infra of cluster + ECSReservedMemory
      architecture   = "x86_64"
    }
  }

  # fargate const
  fargate_instances = {
    "cpu512_mib1024" = {
      cpu    = 512
      memory = 1024
    }
    cpu1024_mib2048 = {
      cpu    = 1024
      memory = 2048
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
    weight                      = 50   # 50% chance
    target_capacity_cpu_percent = 70
    maximum_scaling_step_size   = 1
    minimum_scaling_step_size   = 1
  }
  ec2 = {
    "${local.pricing_name_spot}" = {
      user_data         = <<EOT
          #!/bin/bash
          cat <<'EOF' >> /etc/ecs/ecs.config
              ECS_ENABLE_TASK_IAM_ROLE=true
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
              ECS_ENABLE_TASK_IAM_ROLE=true
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
        key    = "FARGATE_SPOT"
        base   = null # no preferred instance amount
        weight = 50   # 50% chance        
      }
      "${local.pricing_name_on_demand}" = {
        key    = "FARGATE"
        base   = null # no preferred instance amount
        weight = 50   # 50% chance        
      }
    }
  }

  # ECS
  ecs = {
    log = {
      retention_days = 30
      prefix         = "ecs"
    }
    task_definition = {}
    service = {
      deployment_minimum_healthy_percent = 66
    }
  }
}
