# Reproduces the v1 standalone module address.

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

module "coredump_access" {
  source = "../fixtures/v1-coredump-access"

  read_access_expires_at = var.read_access_expires_at
}

output "role_arn" {
  value = module.coredump_access.role_arn
}

output "role_name" {
  value = module.coredump_access.role_name
}

output "policy_name" {
  value = module.coredump_access.policy_name
}
