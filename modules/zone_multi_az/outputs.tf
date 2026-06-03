
output "vpc_id" {
  value = module.regional.vpc_id
}
output "cidr_block" {
  value = module.regional.cidr_block
}
output "ipv6_cidr_block" {
  value = module.regional.ipv6_cidr_block
}
output "network_acl_id" {
  value = module.zonal.network_acl_id
}
output "security_group_id" {
  value = module.regional.security_group_id
}
output "archive_bucket" {
  value = module.regional.archive_bucket
}
output "coredump_bucket" {
  value = module.regional.coredump_bucket
}
output "hosts_cidr_block" {
  value = module.zonal.hosts_cidr_blocks[0]
}
output "hosts_ipv6_cidr_block" {
  value = module.zonal.hosts_ipv6_cidr_blocks[0]
}
output "nat_gateway_id" {
  value = module.regional.nat_gateway_id
}
output "hosts_route_table_id" {
  value = module.regional.hosts_route_table_id
}

output "primary_hosts_subnet_id" {
  value = module.zonal.hosts_subnet_ids[0]
}
output "primary_lb_subnet_id" {
  value = module.zonal.lb_subnet_ids[0]
}
output "primary_natgw_subnet_id" {
  value = module.zonal.natgw_subnet_ids[0]
}

output "hosts_subnet_ids" {
  description = "Map of AZ ID to hosts subnet ID."
  value       = zipmap(local.azs_ordered, module.zonal.hosts_subnet_ids)
}
output "lb_subnet_ids" {
  description = "Map of AZ ID to LB subnet ID."
  value       = zipmap(local.azs_ordered, module.zonal.lb_subnet_ids)
}
output "natgw_subnet_ids" {
  description = "Map of AZ ID to NAT gateway subnet ID."
  value       = zipmap(local.azs_ordered, module.zonal.natgw_subnet_ids)
}
output "eip_ids" {
  description = "Map of AZ ID to NAT gateway EIP allocation ID."
  value       = zipmap(local.azs_ordered, module.regional.eip_ids)
}

output "secondary_cidr_blocks" {
  description = "Map of secondary AZ ID to IPv4 CIDR."
  value       = zipmap(local.secondary_azs, local.secondary_ipv4_cidrs)
}
output "secondary_ipv6_cidr_blocks" {
  description = "Map of secondary AZ ID to IPv6 /56 CIDR."
  value       = zipmap(local.secondary_azs, module.regional.secondary_ipv6_cidr_blocks)
}
