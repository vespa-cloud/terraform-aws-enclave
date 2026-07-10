# Test fixture: composes the root module with the customer-facing submodules,
# mirroring the integration-test template, but with relative sources so the
# local (unreleased) code is what gets planned.

module "enclave" {
  source              = "../.."
  vespa_cloud_account = "786426250597"
  tenant_name         = "vespa"
}

module "zone" {
  source = "../../modules/zone"
  zone   = module.enclave.zones.prod.aws_us_east_1c
  archive_reader_principals = [
    "arn:aws:iam::786426250597:role/vespa.operator.tenant_vespa",
  ]
}

module "zone_multi_az" {
  source          = "../../modules/zone_multi_az"
  zone            = module.enclave.zones.prod.aws_us_east_1
  azs             = ["use1-az1", "use1-az2", "use1-az4", "use1-az5", "use1-az6"]
  primary_zone_az = "use1-az1"
  archive_reader_principals = [
    "arn:aws:iam::786426250597:role/vespa.operator.tenant_vespa",
  ]
}

module "ssh" {
  source              = "../../modules/ssh"
  vespa_cloud_account = module.enclave.vespa_cloud_account
}

module "coredump_access" {
  source                 = "../../modules/coredump-access"
  read_access_expires_at = "2028-01-01T00:00:00Z"
}

output "zones" {
  value = module.enclave.zones
}

output "vespa_host_role" {
  value = module.enclave.vespa_host_role
}
