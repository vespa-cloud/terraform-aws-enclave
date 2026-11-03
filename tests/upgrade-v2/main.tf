# Candidate v2 caller shape after removing the standalone v1 module block.

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

variable "support_data_access_allowed_until" {
  type    = string
  default = null
}

module "enclave" {
  source = "../.."

  tenant_name                       = "vespa"
  vespa_cloud_account               = "786426250597"
  support_data_access_allowed_until = var.support_data_access_allowed_until
}

output "role_arn" {
  value = module.enclave.support_data_read_role_arn
}

output "trusted_principal_arn" {
  value = module.enclave.support_data_read_trusted_principal_arn
}
