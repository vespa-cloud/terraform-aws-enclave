
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
