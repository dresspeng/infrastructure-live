locals {
  # const
  ecs_reserved_memory = 30

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
}
