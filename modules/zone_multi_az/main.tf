
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

  # azs defaults to the AZs Vespa Cloud occupies for this region. Tenants
  # override var.azs to deploy in a different set of AZs.
  effective_azs = var.azs != null ? var.azs : var.zone.az

  cidr_by_az = {
    for az in local.effective_azs :
    az => cidrsubnet(var.ipv4_cidr_base, 7, tonumber(regex("az(\\d+)$", az)[0]) - 1)
  }

  primary_az_id = coalesce(var.primary_zone_az, local.effective_azs[0])
  primary_cidr  = local.cidr_by_az[local.primary_az_id]

  secondary_zones = {
    for az, cidr in local.cidr_by_az : az => cidr if az != local.primary_az_id
  }

  primary_zone = merge(var.zone, { az = [local.primary_az_id] })
}

module "primary" {
  source                    = "../zone"
  is_multi_az               = true
  zone                      = local.primary_zone
  zone_ipv4_cidr            = local.primary_cidr
  archive_reader_principals = var.archive_reader_principals
  custom_ebs_kms_key_policy = var.custom_ebs_kms_key_policy

  extra_ingress_cidr_blocks = values(local.secondary_zones)
  extra_ingress_ipv6_cidr_blocks = [
    for az in keys(local.secondary_zones) :
    aws_vpc_ipv6_cidr_block_association.secondary[az].ipv6_cidr_block
  ]
}

locals {
  # Subnet IDs by role, primary first then secondaries, for NACL / RT association.
  all_hosts_subnet_ids = concat(
    [module.primary.hosts_subnet_id],
    [for s in aws_subnet.hosts : s.id],
  )
  all_lb_subnet_ids = concat(
    [module.primary.lb_subnet_id],
    [for s in aws_subnet.lb : s.id],
  )
  all_natgw_subnet_ids = concat(
    [module.primary.natgw_subnet_id],
    [for s in aws_subnet.natgw : s.id],
  )
}

data "aws_region" "current" {
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

data "aws_availability_zone" "secondary" {
  for_each = local.secondary_zones
  zone_id  = each.key
}

resource "aws_vpc_ipv4_cidr_block_association" "secondary" {
  for_each   = local.secondary_zones
  vpc_id     = module.primary.vpc_id
  cidr_block = each.value
}

resource "aws_vpc_ipv6_cidr_block_association" "secondary" {
  for_each                         = local.secondary_zones
  vpc_id                           = module.primary.vpc_id
  assign_generated_ipv6_cidr_block = true
}

resource "aws_subnet" "hosts" {
  for_each = local.secondary_zones

  vpc_id                          = module.primary.vpc_id
  cidr_block                      = cidrsubnet(each.value, 1, 1)
  ipv6_cidr_block                 = cidrsubnet(aws_vpc_ipv6_cidr_block_association.secondary[each.key].ipv6_cidr_block, 8, 1)
  assign_ipv6_address_on_creation = true
  availability_zone               = data.aws_availability_zone.secondary[each.key].name

  tags = {
    Name      = "${local.zone_name}-subnet-tenant-${each.key}"
    managedby = "vespa-cloud"
    zone      = local.zone_name
    service   = "tenant"
  }

  depends_on = [aws_vpc_ipv4_cidr_block_association.secondary]
}

resource "aws_subnet" "lb" {
  for_each = local.secondary_zones

  vpc_id                          = module.primary.vpc_id
  cidr_block                      = cidrsubnet(each.value, 4, 2)
  ipv6_cidr_block                 = cidrsubnet(aws_vpc_ipv6_cidr_block_association.secondary[each.key].ipv6_cidr_block, 8, 2)
  assign_ipv6_address_on_creation = true
  availability_zone               = data.aws_availability_zone.secondary[each.key].name

  tags = {
    Name      = "${local.zone_name}-subnet-tenantelb-${each.key}"
    managedby = "vespa-cloud"
    zone      = local.zone_name
    service   = "tenantelb"
  }

  depends_on = [aws_vpc_ipv4_cidr_block_association.secondary]
}

resource "aws_subnet" "natgw" {
  for_each = local.secondary_zones

  vpc_id                          = module.primary.vpc_id
  cidr_block                      = cidrsubnet(each.value, 4, 3)
  ipv6_cidr_block                 = cidrsubnet(aws_vpc_ipv6_cidr_block_association.secondary[each.key].ipv6_cidr_block, 8, 3)
  assign_ipv6_address_on_creation = true
  availability_zone               = data.aws_availability_zone.secondary[each.key].name

  tags = {
    Name      = "${local.zone_name}-subnet-natgw-${each.key}"
    managedby = "vespa-cloud"
    zone      = local.zone_name
    service   = "natgw"
  }

  depends_on = [aws_vpc_ipv4_cidr_block_association.secondary]
}

resource "aws_eip" "natgw" {
  for_each = toset(local.effective_azs)
  tags = {
    Name      = "${local.zone_name}-eip-natgw-${each.key}"
    managedby = "vespa-cloud"
  }
}

resource "aws_nat_gateway" "regional" {
  availability_mode = "regional"
  vpc_id            = module.primary.vpc_id

  dynamic "availability_zone_address" {
    for_each = toset(local.effective_azs)
    content {
      availability_zone_id = availability_zone_address.key
      allocation_ids       = [aws_eip.natgw[availability_zone_address.key].id]
    }
  }

  tags = {
    Name      = "${local.zone_name}-natgw"
    managedby = "vespa-cloud"
  }
}

resource "aws_route_table" "hosts" {
  vpc_id = module.primary.vpc_id
  tags = {
    Name      = "${local.zone_name}-rt"
    managedby = "vespa-cloud"
  }
}

resource "aws_route" "hosts_ipv4" {
  route_table_id         = aws_route_table.hosts.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.regional.id
}

resource "aws_route" "hosts_ipv6" {
  route_table_id              = aws_route_table.hosts.id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = module.primary.internet_gateway_id
}

resource "aws_route_table_association" "hosts" {
  for_each       = toset(local.all_hosts_subnet_ids)
  subnet_id      = each.value
  route_table_id = aws_route_table.hosts.id
}

resource "aws_route_table_association" "lb_secondary" {
  for_each       = local.secondary_zones
  subnet_id      = aws_subnet.lb[each.key].id
  route_table_id = module.primary.lb_route_table_id
}

resource "aws_route_table_association" "natgw_secondary" {
  for_each       = local.secondary_zones
  subnet_id      = aws_subnet.natgw[each.key].id
  route_table_id = module.primary.natgw_route_table_id
}

resource "aws_network_acl" "main" {
  vpc_id = module.primary.vpc_id
  subnet_ids = concat(
    local.all_hosts_subnet_ids,
    local.all_lb_subnet_ids,
    local.all_natgw_subnet_ids,
  )
  tags = {
    Name      = "${local.zone_name}-nacl"
    managedby = "vespa-cloud"
  }
}

resource "aws_network_acl_rule" "in_primary_ipv4" {
  #checkov:skip=CKV_AWS_352:All ports open inside the primary CIDR here, but limited by iptables on the host
  network_acl_id = aws_network_acl.main.id
  rule_number    = 100
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = module.primary.cidr_block
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "in_primary_ipv6" {
  #checkov:skip=CKV_AWS_352:All ports open inside the primary CIDR here, but limited by iptables on the host
  network_acl_id  = aws_network_acl.main.id
  rule_number     = 110
  protocol        = "-1"
  rule_action     = "allow"
  ipv6_cidr_block = module.primary.ipv6_cidr_block
  from_port       = 0
  to_port         = 0
}

# Rule numbers are derived from the AZ ordinal so adding or removing a secondary
# AZ does not renumber other rules and force them to be replaced.
resource "aws_network_acl_rule" "in_secondary_ipv4" {
  for_each       = local.secondary_zones
  network_acl_id = aws_network_acl.main.id
  rule_number    = 200 + tonumber(regex("az(\\d+)$", each.key)[0])
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = each.value
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "in_secondary_ipv6" {
  for_each        = local.secondary_zones
  network_acl_id  = aws_network_acl.main.id
  rule_number     = 300 + tonumber(regex("az(\\d+)$", each.key)[0])
  protocol        = "-1"
  rule_action     = "allow"
  ipv6_cidr_block = aws_vpc_ipv6_cidr_block_association.secondary[each.key].ipv6_cidr_block
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

resource "aws_vpc_endpoint" "ecr_s3" {
  vpc_id            = module.primary.vpc_id
  route_table_ids   = [aws_route_table.hosts.id]
  vpc_endpoint_type = "Gateway"
  service_name      = "com.amazonaws.${data.aws_region.current.id}.s3"
  tags = {
    Name      = "vespa-s3gw-${local.zone_name}"
    managedby = "vespa-cloud"
    zone      = local.zone_name
    service   = "s3"
  }
}

