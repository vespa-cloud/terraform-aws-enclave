
locals {
  template_version = "1.0.8"
  zones_by_env = {
    for zone in var.all_zones :
    zone.environment => merge(
      {
        name             = "${zone.environment}.${zone.region}",
        az               = var.az_by_region[zone.region],
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
