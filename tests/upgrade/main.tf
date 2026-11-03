# Exercises the v1 and v2 resource graphs through one stable test module so
# consecutive test runs operate on the same state.

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

variable "read_access_expires_at" {
  type    = string
  default = null
}

variable "support_data_access_allowed_until" {
  type    = string
  default = null
}

module "coredump_access" {
  source = "../fixtures/v1-coredump-access"

  read_access_expires_at = var.read_access_expires_at
}

module "enclave" {
  source = "../.."

  tenant_name                       = "vespa"
  vespa_cloud_account               = "786426250597"
  support_data_access_allowed_until = var.support_data_access_allowed_until
}

output "legacy_role_arn" {
  value = module.coredump_access.role_arn
}

output "legacy_role_name" {
  value = module.coredump_access.role_name
}

output "legacy_policy_name" {
  value = module.coredump_access.policy_name
}

output "support_data_role_arn" {
  value = module.enclave.support_data_read_role_arn
}

output "support_data_trusted_principal_arn" {
  value = module.enclave.support_data_read_trusted_principal_arn
}
