
locals {
  template_version = "1.1.2"
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
  description = "Available zones are listed at https://cloud.vespa.ai/en/reference/zones.html . You reference a zone with `[environment].[region with - replaced by _]` (e.g `prod.aws-us-east-1c`)."
  value = {
    for environment, zones in local.zones_by_env :
    environment => { for zone in zones : replace(zone.region, "-", "_") => zone }
  }
}

output "vespa_cloud_account" {
  description = "The Vespa Cloud AWS account used to manage enclave accounts"
  value       = var.vespa_cloud_account
}
