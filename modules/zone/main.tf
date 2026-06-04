
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

locals {
  zone_az_id = coalesce(var.zone_az, var.zone.az[0])
  zone = merge(
    var.zone,
    {
      az = [local.zone_az_id]
    }
  )
}

module "regional" {
  source                    = "../regional"
  zone                      = local.zone
  is_multi_az               = false
  azs                       = [local.zone_az_id]
  primary_ipv4_cidr         = var.zone_ipv4_cidr
  secondary_ipv4_cidrs      = []
  primary_natgw_subnet_id   = module.zonal.natgw_subnet_ids[0]
  archive_reader_principals = var.archive_reader_principals
  custom_ebs_kms_key_policy = var.custom_ebs_kms_key_policy
}

module "zonal" {
  source            = "../zonal"
  zone              = local.zone
  azs               = [local.zone_az_id]
  vpc_id            = module.regional.vpc_id
  security_group_id = module.regional.security_group_id
  ipv4_cidrs = [
    module.regional.cidr_block,
  ]
  ipv6_cidr_blocks = [
    module.regional.ipv6_cidr_block,
  ]
  hosts_route_table_id = module.regional.hosts_route_table_id
  lb_route_table_id    = module.regional.lb_route_table_id
  natgw_route_table_id = module.regional.natgw_route_table_id
}

# State migration: resources used to live at the top level of this module.
# After the regional / zonal split they live inside the sub-modules. Moved
# blocks preserve existing state without recreation.

moved {
  from = aws_vpc.main
  to   = module.regional.aws_vpc.main
}
moved {
  from = aws_internet_gateway.gw
  to   = module.regional.aws_internet_gateway.gw
}
moved {
  from = aws_route_table.lb
  to   = module.regional.aws_route_table.lb
}
moved {
  from = aws_route.lb_default_ipv4
  to   = module.regional.aws_route.lb_default_ipv4
}
moved {
  from = aws_route.lb_default_ipv6
  to   = module.regional.aws_route.lb_default_ipv6
}
moved {
  from = aws_route_table.natgw
  to   = module.regional.aws_route_table.natgw
}
moved {
  from = aws_route.natgw_ipv4
  to   = module.regional.aws_route.natgw_ipv4
}
moved {
  from = aws_route_table.hosts
  to   = module.regional.aws_route_table.hosts
}
moved {
  from = aws_route.hosts_ipv4
  to   = module.regional.aws_route.hosts_ipv4
}
moved {
  from = aws_route.hosts_ipv6
  to   = module.regional.aws_route.hosts_ipv6
}
moved {
  from = aws_eip.natgw
  to   = module.regional.aws_eip.natgw[0]
}
moved {
  from = aws_nat_gateway.gw
  to   = module.regional.aws_nat_gateway.gw[0]
}
moved {
  from = aws_security_group.sg
  to   = module.regional.aws_security_group.sg
}
moved {
  from = aws_security_group_rule.in_vpc
  to   = module.regional.aws_security_group_rule.in_vpc
}
moved {
  from = aws_security_group_rule.out_any
  to   = module.regional.aws_security_group_rule.out_any
}
moved {
  from = aws_vpc_endpoint.interface
  to   = module.zonal.aws_vpc_endpoint.interface
}
moved {
  from = aws_vpc_endpoint.ecr_s3
  to   = module.regional.aws_vpc_endpoint.ecr_s3
}
moved {
  from = aws_kms_key.ebs
  to   = module.regional.aws_kms_key.ebs
}
moved {
  from = aws_kms_alias.ebs
  to   = module.regional.aws_kms_alias.ebs
}
moved {
  from = aws_kms_key.backup
  to   = module.regional.aws_kms_key.backup
}
moved {
  from = aws_kms_alias.backup
  to   = module.regional.aws_kms_alias.backup
}
moved {
  from = aws_kms_key_policy.backup
  to   = module.regional.aws_kms_key_policy.backup
}
moved {
  from = aws_s3_bucket.backup
  to   = module.regional.aws_s3_bucket.backup
}
moved {
  from = aws_s3_bucket_policy.backup
  to   = module.regional.aws_s3_bucket_policy.backup
}
moved {
  from = aws_s3_bucket_lifecycle_configuration.backup
  to   = module.regional.aws_s3_bucket_lifecycle_configuration.backup
}
moved {
  from = aws_s3_bucket_public_access_block.backup
  to   = module.regional.aws_s3_bucket_public_access_block.backup
}
moved {
  from = aws_s3_bucket_server_side_encryption_configuration.backup
  to   = module.regional.aws_s3_bucket_server_side_encryption_configuration.backup
}
moved {
  from = module.archive
  to   = module.regional.module.archive
}

# Subnets, route-table associations, and the NACL moved into modules/zonal.
moved {
  from = aws_subnet.hosts
  to   = module.zonal.aws_subnet.hosts[0]
}
moved {
  from = aws_subnet.lb
  to   = module.zonal.aws_subnet.lb[0]
}
moved {
  from = aws_subnet.natgw
  to   = module.zonal.aws_subnet.natgw[0]
}
moved {
  from = aws_route_table_association.hosts
  to   = module.zonal.aws_route_table_association.hosts[0]
}
moved {
  from = aws_route_table_association.lb
  to   = module.zonal.aws_route_table_association.lb[0]
}
moved {
  from = aws_route_table_association.natgw
  to   = module.zonal.aws_route_table_association.natgw[0]
}
moved {
  from = aws_network_acl.main
  to   = module.zonal.aws_network_acl.main
}
moved {
  from = aws_network_acl_rule.in_vpc_ipv4
  to   = module.zonal.aws_network_acl_rule.in_vpc_ipv4
}
moved {
  from = aws_network_acl_rule.in_vpc_ipv6
  to   = module.zonal.aws_network_acl_rule.in_vpc_ipv6
}
moved {
  from = aws_network_acl_rule.in_any_ipv4
  to   = module.zonal.aws_network_acl_rule.in_any_ipv4
}
moved {
  from = aws_network_acl_rule.in_any_ipv6
  to   = module.zonal.aws_network_acl_rule.in_any_ipv6
}
moved {
  from = aws_network_acl_rule.in_any_udp_ipv6
  to   = module.zonal.aws_network_acl_rule.in_any_udp_ipv6
}
moved {
  from = aws_network_acl_rule.in_any_https_ipv4
  to   = module.zonal.aws_network_acl_rule.in_any_https_ipv4
}
moved {
  from = aws_network_acl_rule.in_any_https_ipv6
  to   = module.zonal.aws_network_acl_rule.in_any_https_ipv6
}
moved {
  from = aws_network_acl_rule.in_any_icmp_fragmentation_needed
  to   = module.zonal.aws_network_acl_rule.in_any_icmp_fragmentation_needed
}
moved {
  from = aws_network_acl_rule.out_ipv4
  to   = module.zonal.aws_network_acl_rule.out_ipv4
}
moved {
  from = aws_network_acl_rule.out_ipv6
  to   = module.zonal.aws_network_acl_rule.out_ipv6
}
