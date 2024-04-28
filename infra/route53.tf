data "aws_route53_zone" "this" {
  name         = var.domain.zone
  private_zone = false
}