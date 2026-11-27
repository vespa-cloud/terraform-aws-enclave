locals {
  # The release of this module package, read from the VERSION file at the
  # package root. GitHub Actions tags releases from that file, and every zone
  # module compares this value with the release of its own package.
  release = trimspace(file("${path.module}/VERSION"))

  debug_identity_prefix_by_account = {
    "332934501266" = "vespa-debug."
    "786426250597" = "vespa-debug-cd."
  }

  debug_identity_name     = "${local.debug_identity_prefix_by_account[var.vespa_cloud_account]}${var.tenant_name}"
  debug_instance_role_arn = "arn:aws:iam::061361823659:role/${local.debug_identity_name}"
}

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

data "aws_caller_identity" "current" {}

module "provision" {
  source              = "./modules/provision"
  account             = data.aws_caller_identity.current.account_id
  vespa_cloud_account = var.vespa_cloud_account
  tenant_name         = var.tenant_name
}

module "support_data_access" {
  source = "./modules/support-data-access"

  debug_instance_role_arn           = local.debug_instance_role_arn
  support_data_access_allowed_until = var.support_data_access_allowed_until
}
