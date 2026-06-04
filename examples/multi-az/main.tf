
#
# Set up the AWS Terraform Provider to point to the region where
# you want to provision the Vespa Cloud Enclave.
#
provider "aws" {
  region = "us-east-1"
}

#
# Set up the basic module that grants Vespa Cloud permission to
# provision Vespa Cloud resources inside the AWS account.
#
module "enclave" {
  source      = "vespa-cloud/enclave/aws"
  version     = ">= 1.0.0, < 2.0.0"
  tenant_name = "<YOUR-TENANT-HERE>"
}

#
# Set up a multi-AZ zone. The zone spans the Vespa Cloud configserver AZs
# (carried on the zone object) plus any extra AZs listed in var.azs.
# TODO: Update example with a real multi-AZ zone and its AZs.
#
module "zone_prod_us_east_1" {
  source  = "vespa-cloud/enclave/aws//modules/zone_multi_az"
  version = ">= 1.0.0, < 2.0.0"
  zone    = module.enclave.zones.prod.aws_us_east_1

  azs             = ["use1-az2", "use1-az4"]
  primary_zone_az = "use1-az2"
}
