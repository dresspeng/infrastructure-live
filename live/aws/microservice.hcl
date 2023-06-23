locals {
  # const
  ec2_instance_key     = "t3_small"
  fargate_instance_key = 1
  ecs_reserved_memory  = 100
  use_bridge           = true

  # keys
  spot      = "spot"
  on_demand = "on-demand"

  # ec2
  ec2_instances = {
    t3_small = {
      name           = "t3.small"
      cpu            = 2048
      memory         = 2048
      memory_allowed = 1801 # TODO: double check under infra of cluster + ECSReservedMemory
    }
    t3_medium = {
      name           = "t3.medium"
      cpu            = 2048
      memory         = 4096
      memory_allowed = 3828 # TODO: double check under infra of cluster + ECSReservedMemory
    }
  }
  ec2_asg = {
    min_size     = 0
    desired_size = 1
    max_size     = 2
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
  ec2_default = {
    "${local.spot}" = {
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
    "${local.on_demand}" = {
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
  ec2_x64_linux = {
    ami_ssm_architecture = "amazon-linux-2023"
    instance_type        = local.ec2_instances[local.ec2_instance_key].name
  }
  ec2_x64_linux_complete = {
    # local.spot      = merge(local.ec2[local.spot], local.ec2_x64_linux)
    "${local.on_demand}" = merge(local.ec2_default[local.on_demand], local.ec2_x64_linux)
  }

  # fargate
  fargate_instances = {
    1 = {
      cpu    = 512
      memory = 1024
    }
  }
  fargate_x64_linux = {
    os           = "LINUX"
    architecture = "X86_64"
  }
  fargate_default = {
    capacity_provider = {
      "${local.spot}" = {
        base           = null # no preferred instance amount
        weight_percent = 50   # 50% chance
        fargate        = "FARGATE"
      }
      "${local.on_demand}" = {
        base           = null # no preferred instance amount
        weight_percent = 50   # 50% chance
        fargate        = "FARGATE_SPOT"
      }
    }
  }

  fargate_x64_linux_complete = merge(local.fargate_default, local.fargate_x64_linux)

  # ecs
  service_default = {
    task_desired_count                 = 1
    deployment_minimum_healthy_percent = 66
  }
  service_ec2 = merge(local.service_default, {
    use_fargate = false
    deployment_circuit_breaker = {
      enable   = true
      rollback = false
    }
  })
  service_fargate = merge(local.service_default, { use_fargate = true })

  task_definition_default = {}
  task_definition_ec2 = merge(local.task_definition_default, {
    cpu                = local.ec2_instances[local.ec2_instance_key].cpu
    memory             = local.ec2_instances[local.ec2_instance_key].memory_allowed - local.ecs_reserved_memory
    memory_reservation = local.ec2_instances[local.ec2_instance_key].memory_allowed - local.ecs_reserved_memory
  })
  task_definition_fargate = merge(local.task_definition_default, {
    cpu    = local.fargate_instances[local.fargate_instance_key].cpu
    memory = local.fargate_instances[local.fargate_instance_key].memory
  })

  ecs_default = {
    log = {
      retention_days = 30
      prefix         = "aws/ecs"
    }
    bucket_env = {
      force_destroy = false
      versioning    = true
    }
  }
  ecs_ec2     = merge(local.ecs_default, { service = local.service_ec2 })
  ecs_fargate = merge(local.ecs_default, { service = local.service_fargate })
}
