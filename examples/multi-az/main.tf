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
# Set up the VPC for the multi-AZ zone prod.aws-us-east-1.
# The configserver AZs (use1-az2, use1-az4, use1-az6) are always included,
# so this VPC spans use1-az1, use1-az2, use1-az4, use1-az5 and use1-az6.
# Do not change primary_zone_az after apply; it forces VPC replacement.
#
module "zone_prod_us_east_1" {
  source  = "vespa-cloud/enclave/aws//modules/zone_multi_az"
  version = ">= 1.0.0, < 2.0.0"
  zone    = module.enclave.zones.prod.aws_us_east_1

  azs             = ["use1-az1", "use1-az5"]
  primary_zone_az = "use1-az1"
}
