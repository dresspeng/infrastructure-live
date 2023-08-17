locals {
  name      = "vistimi"
  cidr_ipv4 = "1.0.0.0/16"
  # nat       = "az"

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {}
}
