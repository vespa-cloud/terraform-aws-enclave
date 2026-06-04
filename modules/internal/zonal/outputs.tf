
output "hosts_subnet_ids" {
  description = "List of hosts subnet IDs, aligned with var.azs."
  value       = aws_subnet.hosts[*].id
}

output "lb_subnet_ids" {
  description = "List of LB subnet IDs, aligned with var.azs."
  value       = aws_subnet.lb[*].id
}

output "natgw_subnet_ids" {
  description = "List of NAT gateway subnet IDs, aligned with var.azs."
  value       = aws_subnet.natgw[*].id
}

output "hosts_cidr_blocks" {
  description = "List of hosts subnet IPv4 CIDR blocks, aligned with var.azs."
  value       = aws_subnet.hosts[*].cidr_block
}

output "hosts_ipv6_cidr_blocks" {
  description = "List of hosts subnet IPv6 CIDR blocks, aligned with var.azs."
  value       = aws_subnet.hosts[*].ipv6_cidr_block
}

output "availability_zone_names" {
  description = "List of AWS AZ names, aligned with var.azs."
  value       = data.aws_availability_zone.current[*].name
}

output "network_acl_id" {
  value = aws_network_acl.main.id
}
