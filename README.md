# Vespa Cloud Enclave Terraform

This Terraform module handles bootstrapping of an AWS account such that it can
be part of a Vespa Cloud Enclave. Since Vespa Cloud is spread across multiple
AWS regions, one AWS provider must be set up for each region that you want to
host an Enclave in.

After declaring the providers, set up the global `enclave` module. This module
configures the global AWS resources like IAM roles and policies needed to get
started.

Then for each Enclave you want to host in your account - declare the `zone`
module for each Vespa Cloud zone you need.

Example use:

```terraform
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"
}

module "enclave" {
  source      = "vespa-cloud/enclave/aws"
  version     = ">= 1.0.0, < 2.0.0"
  tenant_name = "<vespa cloud tenant>"
}

module "zone_prod_us_east_1c" {
  source  = "vespa-cloud/enclave/aws//modules/zone"
  version = ">= 1.0.0, < 2.0.0"
  zone    = module.enclave.zones.prod.aws_us_east_1c
  providers = {
    aws = aws.us_east_1
  }

  archive_reader_principals = [
    # The user or role ARN that is allowed to read the archive bucket for this zone
  ]
}

module "zone_prod_us_west_2a" {
  source  = "vespa-cloud/enclave/aws//modules/zone"
  version = ">= 1.0.0, < 2.0.0"
  zone    = module.enclave.zones.prod.aws_us_west_2a
  providers = {
    aws = aws.us_west_2
  }

  archive_reader_principals = [
    # The user or role ARN that is allowed to read the archive bucket for this zone
  ]
}
```
