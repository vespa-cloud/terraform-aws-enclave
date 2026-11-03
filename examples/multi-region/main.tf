
#
# Set up the AWS Terraform Provider to point to the region where
# you want to provision the Vespa Cloud Enclave.
#
provider "aws" {
  region = "us-east-1"
  alias  = "us_east_1"

  default_tags {
    tags = {
      Environment = "production"
      Service     = "Vespa"
    }
  }
}

provider "aws" {
  region = "us-west-2"
  alias  = "us_west_2"

  default_tags {
    tags = {
      Environment = "production"
      Service     = "Vespa"
    }
  }
}

#
# Set up the basic module that grants Vespa Cloud permission to
# provision Vespa Cloud resources inside the AWS account.
#
module "enclave" {
  source      = "vespa-cloud/enclave/aws"
  version     = "~> 2.0"
  tenant_name = "<YOUR-TENANT-HERE>"

  # Set this when Vespa Cloud support asks for read access to encrypted heap
  # dumps or native core dumps.
  # support_data_access_allowed_until = "2026-10-01T00:00:00Z"

  providers = {
    aws = aws.us_east_1
  }
}

#
# Enable SSH access for the Vespa team
#
# module "ssh" {
#   source  = "vespa-cloud/enclave/aws//modules/ssh"
#   vespa_cloud_account = module.enclave.vespa_cloud_account
#   providers = {
#     aws = aws.us_east_1
#   }
# }

#
# Set up the VPC that will contain the Enclaved Vespa appplication.
#

#
# Set up the VPC that contains the Enclaved Vespa appplication's dev and perf zones.
#
module "zone_dev_us_east_1c" {
  source  = "vespa-cloud/enclave/aws//modules/zone"
  version = "~> 2.0"
  zone    = module.enclave.zones.dev.aws_us_east_1c
  providers = {
    aws = aws.us_east_1
  }
}

#
# Then, we set up the two zones that are used for the CI/CD deployment
# pipline that Vespa Cloud supports.
#
module "zone_test_us_east_1c" {
  source  = "vespa-cloud/enclave/aws//modules/zone"
  version = "~> 2.0"
  zone    = module.enclave.zones.test.aws_us_east_1c
  providers = {
    aws = aws.us_east_1
  }
}

module "zone_staging_us_east_1c" {
  source  = "vespa-cloud/enclave/aws//modules/zone"
  version = "~> 2.0"
  zone    = module.enclave.zones.staging.aws_us_east_1c
  providers = {
    aws = aws.us_east_1
  }
}

#
#  Then we set up two zones that production deployments go to.
#
module "zone_prod_us_east_1c" {
  source  = "vespa-cloud/enclave/aws//modules/zone"
  version = "~> 2.0"
  zone    = module.enclave.zones.prod.aws_us_east_1c
  providers = {
    aws = aws.us_east_1
  }
}

module "zone_prod_us_west_1a" {
  source  = "vespa-cloud/enclave/aws//modules/zone"
  version = "~> 2.0"
  zone    = module.enclave.zones.prod.aws_us_west_2a
  providers = {
    aws = aws.us_west_2
  }
}
