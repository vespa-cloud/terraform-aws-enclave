
#
# Sett up the AWS Terraform Provider to point to the region where
# your want to provision the Vespa Cloud Enclave.
#
provider "aws" {
  region = "us-east-1"
  alias  = "us_east_1"
}

provider "aws" {
  region = "us-west-2"
  alias  = "us_west_2"
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

#
# First we set up the two zones that are used for the CI/CD deployment
# pipline that Vespa Cloud supports.
#
module "zone_test_us_east_1c" {
  source = "vespa-cloud/terraform-aws-enclave/modules/zone"
  zone   = module.enclave.zones.test.us_east_1c
}

module "zone_staging_us_east_1c" {
  source = "vespa-cloud/terraform-aws-enclave/modules/zone"
  zone   = module.enclave.zones.staging.us_east_1c
}

#
#  Then we set up two zones that production deployments go to.
#
module "zone_prod_us_east_1c" {
  source = "vespa-cloud/terraform-aws-enclave/modules/zone"
  zone   = module.enclave.zones.prod.us_east_1c
}

module "zone_prod_us_west_1a" {
  source = "vespa-cloud/terraform-aws-enclave/modules/zone"
  zone   = module.enclave.zones.prod.us_west_1a
}
