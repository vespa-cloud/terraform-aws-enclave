# Test fixture: pairs the modules from this checkout with release 2.0.0, the
# last release in which zone objects carry template_version and the zone
# modules do not check the enclave module's release.

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# The enclave module from this checkout with zone modules from release 2.0.0.
# Those zone modules must reject its zone objects.

module "enclave" {
  source      = "../.."
  tenant_name = "vespa"
}

module "published_zone" {
  #checkov:skip=CKV_TF_1:The test needs this exact published release
  source  = "vespa-cloud/enclave/aws//modules/zone"
  version = "2.0.0"
  zone    = module.enclave.zones.prod.aws_us_east_1c
}

module "published_zone_multi_az" {
  #checkov:skip=CKV_TF_1:The test needs this exact published release
  source          = "vespa-cloud/enclave/aws//modules/zone_multi_az"
  version         = "2.0.0"
  zone            = module.enclave.zones.prod.aws_us_east_1
  primary_zone_az = module.enclave.zones.prod.aws_us_east_1.configserver_az[0]
}

# The enclave module from release 2.0.0 with the zone modules from this
# checkout. These zone modules must reject its zone objects.

module "published_enclave" {
  #checkov:skip=CKV_TF_1:The test needs this exact published release
  source      = "vespa-cloud/enclave/aws"
  version     = "2.0.0"
  tenant_name = "vespa"
}

module "zone" {
  source = "../../modules/zone"
  zone   = module.published_enclave.zones.prod.aws_us_east_1c
}

module "zone_multi_az" {
  source          = "../../modules/zone_multi_az"
  zone            = module.published_enclave.zones.prod.aws_us_east_1
  primary_zone_az = module.published_enclave.zones.prod.aws_us_east_1.configserver_az[0]
}
