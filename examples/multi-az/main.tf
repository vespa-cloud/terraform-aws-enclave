#
# Set up the AWS Terraform Provider to point to the region where
# you want to provision the Vespa Cloud Enclave.
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
# Set up the VPC for the multi-AZ zone prod.aws-us-east-1.
# The configserver AZs (use1-az2, use1-az4, use1-az6) are always included,
# so this VPC spans use1-az1, use1-az2, use1-az4, use1-az5 and use1-az6.
# Do not change primary_zone_az after apply; it forces VPC replacement.
#
module "zone_prod_us_east_1" {
  #checkov:skip=CKV_TF_1:Registry example uses a version constraint for customer consumption
  source  = "vespa-cloud/enclave/aws//modules/zone_multi_az"
  version = local.enclave_version
  zone    = module.enclave.zones.prod.aws_us_east_1

  azs             = ["use1-az1", "use1-az5"]
  primary_zone_az = "use1-az1"
}
