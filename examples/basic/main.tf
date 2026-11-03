
#
# Set up the AWS Terraform Provider to point to the region where
# your want to provision the Vespa Cloud Enclave.
#
provider "aws" {
  region = "us-east-1"
}

#
# Set up the basic module that grants Vespa Cloud permission to
# provision Vespa Cloud resources inside the AWS account.
#
module "enclave" {
  #checkov:skip=CKV_TF_1:Registry example uses a version constraint for customer consumption
  source      = "vespa-cloud/enclave/aws"
  version     = "~> 2.0"
  tenant_name = "<YOUR-TENANT-HERE>"
}

#
# Set up the VPC that will contain the Enclaved Vespa application for the dev environment.
#
module "zone_dev_us_east_1c" {
  #checkov:skip=CKV_TF_1:Registry example uses a version constraint for customer consumption
  source  = "vespa-cloud/enclave/aws//modules/zone"
  version = "~> 2.0"
  zone    = module.enclave.zones.dev.aws_us_east_1c
}
