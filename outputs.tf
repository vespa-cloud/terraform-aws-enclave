
locals {
  template_version = "1.0.6"
  az_by_region = {
    aws-us-east-1c      = "use1-az6",
    aws-us-west-2a      = "usw2-az1",
    aws-eu-west-1a      = "euw1-az2",
    aws-ap-northeast-1a = "apne1-az4",
  }
  zones_by_env = {
    for zone in var.all_zones :
    zone.environment => merge(
      {
        name             = "${zone.environment}.${zone.region}",
        az               = local.az_by_region[zone.region],
        template_version = local.template_version,
      },
      zone
    )...
  }
}

output "zones" {
  value = {
    for environment, zones in local.zones_by_env :
    environment => { for zone in zones : replace(zone.region, "-", "_") => zone }
  }
}

output "vespa_cloud_account" {
  value = var.vespa_cloud_account
}
