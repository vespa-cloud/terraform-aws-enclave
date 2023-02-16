
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
  source      = "vespa-cloud/terraform-aws-enclave"
  tenant_name = "<YOUR-TENANT-HERE>"
}

#
# Set up the VPC that will contain the Enclaved Vespa appplication.
#
module "zone_dev_us_east_1c" {
  source = "vespa-cloud/terraform-aws-enclave/modules/zone"
  zone   = module.enclave.zones.dev.us_east_1c
}
