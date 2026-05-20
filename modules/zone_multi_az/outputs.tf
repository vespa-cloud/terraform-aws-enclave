
output "vpc_id" {
  value = module.primary.vpc_id
}
output "cidr_block" {
  value = module.primary.cidr_block
}
output "ipv6_cidr_block" {
  value = module.primary.ipv6_cidr_block
}
output "network_acl_id" {
  value = aws_network_acl.main.id
}
output "security_group_id" {
  value = module.primary.security_group_id
}
output "archive_bucket" {
  value = module.primary.archive_bucket
}
output "hosts_cidr_block" {
  value = module.primary.hosts_cidr_block
}
output "hosts_ipv6_cidr_block" {
  value = module.primary.hosts_ipv6_cidr_block
}
output "nat_gateway_id" {
  value = aws_nat_gateway.regional.id
}
output "hosts_route_table_id" {
  value = aws_route_table.hosts.id
}

output "primary_hosts_subnet_id" {
  value = module.primary.hosts_subnet_id
}
output "primary_lb_subnet_id" {
  value = module.primary.lb_subnet_id
}
output "primary_natgw_subnet_id" {
  value = module.primary.natgw_subnet_id
}

output "hosts_subnet_ids" {
  value = merge(
    { (module.primary.availability_zone_id) = module.primary.hosts_subnet_id },
    { for az, _ in local.secondary_zones : az => aws_subnet.hosts[az].id },
  )
}
output "lb_subnet_ids" {
  value = merge(
    { (module.primary.availability_zone_id) = module.primary.lb_subnet_id },
    { for az, _ in local.secondary_zones : az => aws_subnet.lb[az].id },
  )
}
output "natgw_subnet_ids" {
  value = merge(
    { (module.primary.availability_zone_id) = module.primary.natgw_subnet_id },
    { for az, _ in local.secondary_zones : az => aws_subnet.natgw[az].id },
  )
}
output "eip_ids" {
  value = { for az in local.effective_azs : az => aws_eip.natgw[az].id }
}

output "secondary_cidr_blocks" {
  value = local.secondary_zones
}
output "secondary_ipv6_cidr_blocks" {
  value = { for az, _ in local.secondary_zones : az => aws_vpc_ipv6_cidr_block_association.secondary[az].ipv6_cidr_block }
}
