
output "vpc_id" {
  value = aws_vpc.main.id
}

output "cidr_block" {
  value = aws_vpc.main.cidr_block
}

output "ipv6_cidr_block" {
  value = aws_vpc.main.ipv6_cidr_block
}

output "secondary_ipv6_cidr_blocks" {
  description = "IPv6 /56 CIDR blocks for the secondary AZs, aligned with var.azs[1:]."
  value       = aws_vpc_ipv6_cidr_block_association.secondary[*].ipv6_cidr_block
}

output "internet_gateway_id" {
  value = aws_internet_gateway.gw.id
}

output "hosts_route_table_id" {
  value = aws_route_table.hosts.id
}

output "lb_route_table_id" {
  value = aws_route_table.lb.id
}

output "natgw_route_table_id" {
  value = aws_route_table.natgw.id
}

output "security_group_id" {
  value = aws_security_group.sg.id
}

output "nat_gateway_id" {
  value = var.is_multi_az ? aws_nat_gateway.regional[0].id : aws_nat_gateway.gw[0].id
}

output "eip_ids" {
  description = "Allocation IDs for the NAT gateway EIPs, aligned with var.azs."
  value       = aws_eip.natgw[*].id
}

output "archive_bucket" {
  value = module.archive.bucket
}
