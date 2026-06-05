
output "network_acl_id" {
  value = module.zonal.network_acl_id
}
output "security_group_id" {
  value = module.regional.security_group_id
}
output "vpc_id" {
  value = module.regional.vpc_id
}
output "cidr_block" {
  value = module.regional.cidr_block
}
output "ipv6_cidr_block" {
  value = module.regional.ipv6_cidr_block
}
output "hosts_cidr_block" {
  value = module.zonal.hosts_cidr_blocks[0]
}
output "hosts_ipv6_cidr_block" {
  value = module.zonal.hosts_ipv6_cidr_blocks[0]
}
output "hosts_subnet_id" {
  value = module.zonal.hosts_subnet_ids[0]
}
output "archive_bucket" {
  value = module.regional.archive_bucket
}

output "lb_subnet_id" {
  value = module.zonal.lb_subnet_ids[0]
}
output "natgw_subnet_id" {
  value = module.zonal.natgw_subnet_ids[0]
}
output "lb_route_table_id" {
  value = module.regional.lb_route_table_id
}
output "natgw_route_table_id" {
  value = module.regional.natgw_route_table_id
}
output "internet_gateway_id" {
  value = module.regional.internet_gateway_id
}
output "availability_zone_id" {
  value = local.zone_az_id
}
output "availability_zone_name" {
  value = module.zonal.availability_zone_names[0]
}
