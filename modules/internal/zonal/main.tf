
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

data "aws_region" "current" {}

data "aws_availability_zone" "current" {
  count   = length(var.azs)
  zone_id = var.azs[count.index]
}

locals {
  is_multi_az = length(var.azs) > 1

  # Per-AZ infix inserted into subnet Name tags in multi-AZ zones (e.g. "-az4")
  az_name_infix = [
    for az in var.azs : local.is_multi_az ? "-${regex("az\\d+$", az)}" : ""
  ]
}

resource "terraform_data" "validations" {
  lifecycle {
    precondition {
      condition     = length(var.ipv4_cidrs) == length(var.azs)
      error_message = "ipv4_cidrs must have the same length as azs."
    }
    precondition {
      condition     = length(var.ipv6_cidr_blocks) == length(var.azs)
      error_message = "ipv6_cidr_blocks must have the same length as azs."
    }
  }
}

# Subnets
#
# Each AZ slice is a /16, further divided in the following networks:
#
# name   prefix   address count  usable count
# hosts  17       32768          32766
# lb     20       4096           4094
# natgw  20       4096           4094

resource "aws_subnet" "hosts" {
  count                           = length(var.azs)
  vpc_id                          = var.vpc_id
  cidr_block                      = cidrsubnet(var.ipv4_cidrs[count.index], 1, 1)
  ipv6_cidr_block                 = cidrsubnet(var.ipv6_cidr_blocks[count.index], 8, 1)
  assign_ipv6_address_on_creation = true
  availability_zone               = data.aws_availability_zone.current[count.index].name
  tags = {
    Name      = "${var.zone.tag}${local.az_name_infix[count.index]}-subnet-tenant"
    managedby = "vespa-cloud"
    zone      = var.zone.name
    service   = "tenant"
  }
}

resource "aws_subnet" "lb" {
  count                           = length(var.azs)
  vpc_id                          = var.vpc_id
  cidr_block                      = cidrsubnet(var.ipv4_cidrs[count.index], 4, 2)
  ipv6_cidr_block                 = cidrsubnet(var.ipv6_cidr_blocks[count.index], 8, 2)
  assign_ipv6_address_on_creation = true
  availability_zone               = data.aws_availability_zone.current[count.index].name
  tags = {
    Name      = "${var.zone.tag}${local.az_name_infix[count.index]}-subnet-tenantelb"
    managedby = "vespa-cloud"
    zone      = var.zone.name
    service   = "tenantelb"
  }
}

resource "aws_subnet" "natgw" {
  count                           = length(var.azs)
  vpc_id                          = var.vpc_id
  cidr_block                      = cidrsubnet(var.ipv4_cidrs[count.index], 4, 3)
  ipv6_cidr_block                 = cidrsubnet(var.ipv6_cidr_blocks[count.index], 8, 3)
  assign_ipv6_address_on_creation = true
  availability_zone               = data.aws_availability_zone.current[count.index].name
  tags = {
    Name      = "${var.zone.name}${local.az_name_infix[count.index]}-subnet-natgw"
    managedby = "vespa-cloud"
    zone      = var.zone.name
    service   = "natgw"
  }
}

resource "aws_route_table_association" "hosts" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.hosts[count.index].id
  route_table_id = var.hosts_route_table_id
}

resource "aws_route_table_association" "lb" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.lb[count.index].id
  route_table_id = var.lb_route_table_id
}

resource "aws_route_table_association" "natgw" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.natgw[count.index].id
  route_table_id = var.natgw_route_table_id
}

# Interface VPC endpoints. These live here, next to the hosts subnet, so the
# replace_triggered_by below can reference the subnet directly. The endpoints
# are placed in the primary AZ hosts subnet (index 0).

resource "aws_vpc_endpoint" "interface" {
  for_each            = toset(["ecr.api", "ecr.dkr", "ssm", "ssmmessages", "ec2messages", "sts"])
  vpc_id              = var.vpc_id
  subnet_ids          = [aws_subnet.hosts[0].id]
  security_group_ids  = [var.security_group_id]
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.key}"
  tags = {
    Name      = "vespa-${replace(each.key, ".", "-")}-${var.zone.name}"
    managedby = "vespa-cloud"
  }
  # This has an interface in a subnet. If the subnet used by this is replaced,
  # we also have to replace this
  lifecycle {
    replace_triggered_by = [aws_subnet.hosts[0].id]
  }
}

# Network ACL — single per VPC, lives in zonal because subnet_ids reference subnets owned here.

resource "aws_network_acl" "main" {
  vpc_id = var.vpc_id
  subnet_ids = concat(
    aws_subnet.hosts[*].id,
    aws_subnet.lb[*].id,
    aws_subnet.natgw[*].id,
  )
  tags = {
    Name      = "${var.zone.name}-nacl"
    managedby = "vespa-cloud"
  }
}

resource "aws_network_acl_rule" "in_vpc_ipv4" {
  #checkov:skip=CKV_AWS_352:All ports open inside VPC here, but limited by iptables on the host
  network_acl_id = aws_network_acl.main.id
  rule_number    = 100
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.ipv4_cidrs[0]
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "in_vpc_ipv6" {
  #checkov:skip=CKV_AWS_352:All ports open inside VPC here, but limited by iptables on the host
  network_acl_id  = aws_network_acl.main.id
  rule_number     = 110
  protocol        = "-1"
  rule_action     = "allow"
  ipv6_cidr_block = var.ipv6_cidr_blocks[0]
  from_port       = 0
  to_port         = 0
}

resource "aws_network_acl_rule" "in_secondary_ipv4" {
  #checkov:skip=CKV_AWS_352:All ports open inside the secondary CIDR here, but limited by iptables on the host
  count          = length(var.azs) - 1
  network_acl_id = aws_network_acl.main.id
  rule_number    = 200 + count.index + 1
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.ipv4_cidrs[count.index + 1]
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "in_secondary_ipv6" {
  #checkov:skip=CKV_AWS_352:All ports open inside the secondary CIDR here, but limited by iptables on the host
  count           = length(var.azs) - 1
  network_acl_id  = aws_network_acl.main.id
  rule_number     = 300 + count.index + 1
  protocol        = "-1"
  rule_action     = "allow"
  ipv6_cidr_block = var.ipv6_cidr_blocks[count.index + 1]
  from_port       = 0
  to_port         = 0
}

resource "aws_network_acl_rule" "in_any_ipv4" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 120
  protocol       = "6"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "in_any_ipv6" {
  network_acl_id  = aws_network_acl.main.id
  rule_number     = 130
  protocol        = "6"
  rule_action     = "allow"
  ipv6_cidr_block = "::/0"
  from_port       = 1024
  to_port         = 65535
}

resource "aws_network_acl_rule" "in_any_udp_ipv6" {
  network_acl_id  = aws_network_acl.main.id
  rule_number     = 131
  protocol        = "17"
  rule_action     = "allow"
  ipv6_cidr_block = "::/0"
  from_port       = 1024
  to_port         = 65535
}

resource "aws_network_acl_rule" "in_any_https_ipv4" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 132
  protocol       = "6"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "in_any_https_ipv6" {
  network_acl_id  = aws_network_acl.main.id
  rule_number     = 134
  protocol        = "6"
  rule_action     = "allow"
  ipv6_cidr_block = "::/0"
  from_port       = 443
  to_port         = 443
}

# Permitted under AWS-4007/4008 baseline - ideally we should also permit ICMPv6 "Too Big", see PCLOUD-7589
resource "aws_network_acl_rule" "in_any_icmp_fragmentation_needed" {
  #checkov:skip=CKV_AWS_352:All ports open here, but limited by iptables on the host
  network_acl_id = aws_network_acl.main.id
  rule_number    = 140
  protocol       = "1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  icmp_code      = 4
  icmp_type      = 3
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "out_ipv4" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 100
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
  egress         = true
}

resource "aws_network_acl_rule" "out_ipv6" {
  network_acl_id  = aws_network_acl.main.id
  rule_number     = 110
  protocol        = "-1"
  rule_action     = "allow"
  ipv6_cidr_block = "::/0"
  from_port       = 0
  to_port         = 0
  egress          = true
}
