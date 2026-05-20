
output "network_acl_id" {
  value = aws_network_acl.main[0].id
}
output "security_group_id" {
  value = aws_security_group.sg.id
}
output "vpc_id" {
  value = aws_vpc.main.id
}
output "cidr_block" {
  value = aws_vpc.main.cidr_block
}
output "ipv6_cidr_block" {
  value = aws_vpc.main.ipv6_cidr_block
}
output "hosts_cidr_block" {
  value = local.hosts_cidr_block
}
output "hosts_ipv6_cidr_block" {
  value = local.hosts_ipv6_cidr_block
}
output "hosts_subnet_id" {
  value = aws_subnet.hosts.id
}
output "archive_bucket" {
  value = module.archive.bucket
}

output "lb_subnet_id" {
  value = aws_subnet.lb.id
}
output "natgw_subnet_id" {
  value = aws_subnet.natgw.id
}
output "lb_route_table_id" {
  value = aws_route_table.lb.id
}
output "natgw_route_table_id" {
  value = aws_route_table.natgw.id
}
output "internet_gateway_id" {
  value = aws_internet_gateway.gw.id
}
output "availability_zone_id" {
  value = local.zone_az_id
}
output "availability_zone_name" {
  value = data.aws_availability_zone.current.name
}
