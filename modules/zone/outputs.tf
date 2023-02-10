
output "network_acl_id" {
  value = aws_network_acl.main.id
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
