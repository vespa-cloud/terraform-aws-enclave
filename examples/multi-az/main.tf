
terraform {
  required_version = ">= 1.7.0"
}

provider "aws" {
  region = "us-east-1"
}

module "enclave" {
  source      = "../.."
  tenant_name = "<YOUR-TENANT-HERE>"
}

// TODO: Update example with real zone and AZs
module "zone_prod_us_east_1" {
  source          = "../../modules/zone_multi_az"
  zone            = module.enclave.zones.prod.aws_us_east_1
  azs             = ["use1-az2", "use1-az4"]
  primary_zone_az = "use1-az2"
}
