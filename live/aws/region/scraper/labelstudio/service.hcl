locals {

  # vpc = {
  #   id   = "vpc-0d5c1d5379f616e2f"
  # }

  iam = {
    scope        = "accounts"
    requires_mfa = false
  }

  bucket_label = {
    force_destroy = false
    versioning    = true
  }

  create_acm_certificate = true

  tags = {}
}
