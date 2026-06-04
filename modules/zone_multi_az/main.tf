
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.24.0"
    }
  }
}

locals {
  zone_name = var.zone.name

  # Effective AZs are the union of tenant-specified AZs (var.azs, may be null)
  # and the Vespa Cloud configserver AZs (var.zone.configserver_az). Configserver
  # AZs are always included so the enclave VPC can reach configservers.
  tenant_azs    = var.azs != null ? var.azs : []
  effective_azs = sort(distinct(concat(local.tenant_azs, var.zone.configserver_az)))

  cidr_by_az = {
    for az in local.effective_azs :
    az => cidrsubnet(var.ipv4_cidr_base, 7, tonumber(regex("az(\\d+)$", az)[0]) - 1)
  }

  primary_az_id = coalesce(var.primary_zone_az, local.effective_azs[0])
  primary_cidr  = local.cidr_by_az[local.primary_az_id]

  # Ordered AZ list used for count-indexed resources: primary first, then the
  # remaining AZs in sorted order so additions or removals of tenant AZs do not
  # silently reorder existing resources.
  secondary_azs = [for az in local.effective_azs : az if az != local.primary_az_id]
  azs_ordered   = concat([local.primary_az_id], local.secondary_azs)

  secondary_ipv4_cidrs = [for az in local.secondary_azs : local.cidr_by_az[az]]

  primary_zone = merge(var.zone, { az = [local.primary_az_id] })
}

resource "terraform_data" "validations" {
  lifecycle {
    precondition {
      condition     = length(local.effective_azs) == 1 || var.primary_zone_az != null
      error_message = "primary_zone_az must be set explicitly when deploying in more than one AZ. The primary AZ owns the VPC's primary CIDR block; changing it later forces VPC and subnet replacement, so the choice must be deliberate."
    }
    precondition {
      condition     = var.primary_zone_az == null || contains(local.effective_azs, var.primary_zone_az)
      error_message = format("primary_zone_az %q must be one of the deployed AZs %v", var.primary_zone_az, local.effective_azs)
    }
    precondition {
      condition     = alltrue([for az in local.effective_azs : can(regex("az[1-9]\\d*$", az))])
      error_message = format("Every deployed AZ ID must end in 'azN' with N>=1 (e.g. 'use1-az3'). Got %v.", local.effective_azs)
    }
  }
}

module "regional" {
  source                    = "../regional"
  zone                      = local.primary_zone
  is_multi_az               = true
  azs                       = local.azs_ordered
  primary_ipv4_cidr         = local.primary_cidr
  secondary_ipv4_cidrs      = local.secondary_ipv4_cidrs
  archive_reader_principals = var.archive_reader_principals
  custom_ebs_kms_key_policy = var.custom_ebs_kms_key_policy
  # primary_natgw_subnet_id unused when is_multi_az = true
}

module "zonal" {
  source            = "../zonal"
  zone              = local.primary_zone
  azs               = local.azs_ordered
  vpc_id            = module.regional.vpc_id
  security_group_id = module.regional.security_group_id
  ipv4_cidrs = concat(
    [module.regional.cidr_block],
    local.secondary_ipv4_cidrs,
  )
  ipv6_cidr_blocks = concat(
    [module.regional.ipv6_cidr_block],
    module.regional.secondary_ipv6_cidr_blocks,
  )
  hosts_route_table_id = module.regional.hosts_route_table_id
  lb_route_table_id    = module.regional.lb_route_table_id
  natgw_route_table_id = module.regional.natgw_route_table_id
}
