locals {
  prefix_alternative_names = compact([
    var.domain.prefix != null ? "*.${var.domain.prefix}" : "*",
    var.domain.prefix,
  ])
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "5.0.0"

  domain_name = join(".", compact([var.domain.prefix, var.domain.zone]))
  zone_id     = data.aws_route53_zone.this.zone_id

  validation_method = "DNS"

  subject_alternative_names = [for prefix_name in local.prefix_alternative_names : "${prefix_name}.${var.domain.zone}"]

  create_certificate     = true
  create_route53_records = true

  wait_for_validation = true
  validation_timeout  = "20m"

  tags = var.tags
}