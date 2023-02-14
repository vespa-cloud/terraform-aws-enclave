# Vespa Cloud Enclave Terraform

This Terraform module handles bootstrapping of an AWS account such that
it can be part of a Vespa Cloud Enclave.  Since Vespa Cloud is spread
across multiple AWS regions, one AWS provider must be set up for each
region that you want to host an Enclave in.

After declaring the providers, set up the global `enclave` module.
This module configures the global AWS resources like IAM roles and
policies needed to get started.

Then for each Enclave you want to host in your account - declare the
`zone` module for each Vespa Cloud zone you need.  

Example use:
```terraform
provider "aws" {
    profile = "athens"
    alias = "us_east_1"
    region = "us-east-1"
}

provider "aws" {
    profile = "athens"
    alias = "us_west_2"
    region = "us-west-2"
}

module "enclave" {
    source = "vespa-cloud/terraform-aws-enclave"
    tenant_name = "vespa"
}

module "zone_prod_us_east_1c" {
    source = vespa-cloud/terraform-aws-enclave/modules/zone"
    zone = module.enclave.zones.prod.aws_us_east_1c
    providers = {
        aws = aws.us_east_1
    }
}

module "zone_prod_us_west_2a" {
    source = "vespa-cloud/terraform-aws-enclave/modules/zone"
    zone = module.enclave.zones.prod.aws_us_west_2a
    providers = {
      aws = aws.us_west_2
    }
}
```