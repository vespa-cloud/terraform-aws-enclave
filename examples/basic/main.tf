
#
# Set up the AWS Terraform Provider to point to the region where
# your want to provision the Vespa Cloud Enclave.
#
provider "aws" {
  region = "us-east-1"
}

#
# The release of the Vespa Cloud Enclave modules to use. The enclave module
# and all its zone modules must be installed at the same release.
# Replace it with the latest release listed at
# https://github.com/vespa-cloud/terraform-aws-enclave/releases
#
# Referring to a local value in a module's version requires Terraform >= 1.15
# or OpenTofu >= 1.8. With an older version, write this version as a literal
# in every module block instead.
#
locals {
  enclave_version = "3.0.0"
}

#
# Set up the basic module that grants Vespa Cloud permission to
# provision Vespa Cloud resources inside the AWS account.
#
module "enclave" {
  #checkov:skip=CKV_TF_1:Registry example uses a version constraint for customer consumption
  source      = "vespa-cloud/enclave/aws"
  version     = local.enclave_version
  tenant_name = "<YOUR-TENANT-HERE>"
}

#
# Set up the VPC that will contain the Enclaved Vespa application for the dev environment.
#
module "zone_dev_us_east_1c" {
  #checkov:skip=CKV_TF_1:Registry example uses a version constraint for customer consumption
  source  = "vespa-cloud/enclave/aws//modules/zone"
  version = local.enclave_version
  zone    = module.enclave.zones.dev.aws_us_east_1c
}
