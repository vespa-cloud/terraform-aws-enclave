
locals {
  zones_by_env = {
    for zone in var.all_zones :
    zone.environment => merge(
      {
        name = "${zone.environment}.${zone.region}",
        # Single-AZ regions carry their AZ ID here. Multi-AZ regions are absent
        # from az_by_region (their AZs come from configserver_az / the
        # zone_multi_az azs variable), so az is null for them.
        az               = try(var.az_by_region[zone.region], null),
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

output "vespa_host_role" {
  description = "The AWS role assigned to Vespa Cloud hosts"
  value       = "vespa.tenant.${var.tenant_name}.aws-${data.aws_caller_identity.current.account_id}.tenant-host-service"
}

output "support_data_read_role_arn" {
  description = "ARN of the customer support-data read role, or null when no access is granted"
  value       = module.support_data_access.role_arn

  precondition {
    condition     = length(local.debug_identity_name) <= 64
    error_message = "The tenant name is too long for the tenant-specific debug IAM role name, which must not exceed 64 characters."
  }
}

output "support_data_read_trusted_principal_arn" {
  description = "ARN of the tenant-specific Vespa Cloud role trusted for support-data access, or null when no access is granted"
  value       = module.support_data_access.trusted_principal_arn
}
