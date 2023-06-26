
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

locals {
  vespa_cloud_account = var.is_cd ? "786426250597" : "332934501266"
}

data "aws_caller_identity" "current" {}

module "provision" {
  source              = "./modules/provision"
  account             = data.aws_caller_identity.current.account_id
  vespa_cloud_account = local.vespa_cloud_account
  tenant_name         = var.tenant_name
  is_cd               = var.is_cd
}
