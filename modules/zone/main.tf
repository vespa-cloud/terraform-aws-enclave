
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

locals {
  hosts_cidr_block      = cidrsubnet(var.zone_ipv4_cidr, 1, 1)
  hosts_ipv6_cidr_block = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, 1)
}

data "aws_availability_zone" "current" {
  zone_id = var.zone.az
}

module "archive" {
  source = "../archive"
  zone   = var.zone
}

resource "aws_vpc" "main" {
  cidr_block                       = var.zone_ipv4_cidr
  assign_generated_ipv6_cidr_block = true
  enable_dns_hostnames             = true
  tags = {
    Name      = var.zone.name
    managedby = "vespa-cloud"
  }
}

# Subnets
#
# A zone in an external account should be assigned a subnet with prefix length 20, which does not overlap with any other
# subnets used by the zone (in any account). A unit test verifies that subnets do not overlap.
#
# The assigned prefix is further divided in the following networks:
#
# name   prefix   address count  usable count
# lb     24       256            254
# hosts  21       2048           2046

resource "aws_subnet" "hosts" {
  vpc_id                          = aws_vpc.main.id
  cidr_block                      = local.hosts_cidr_block
  ipv6_cidr_block                 = local.hosts_ipv6_cidr_block
  assign_ipv6_address_on_creation = true
  availability_zone               = data.aws_availability_zone.current.name
  tags = {
    Name      = "${var.zone.name}-subnet-tenant"
    managedby = "vespa-cloud"
  }
}

resource "aws_subnet" "lb" {
  vpc_id                          = aws_vpc.main.id
  cidr_block                      = cidrsubnet(var.zone_ipv4_cidr, 4, 2)
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, 2)
  assign_ipv6_address_on_creation = true
  availability_zone               = data.aws_availability_zone.current.name
  tags = {
    Name      = "${var.zone.name}-subnet-tenantelb"
    managedby = "vespa-cloud"
  }
}

# Gateways

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name      = "vespa-igw"
    managedby = "vespa-cloud"
  }
}


# Routing tables

resource "aws_route_table" "hosts" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name      = var.zone.name
    managedby = "vespa-cloud"
  }
}

resource "aws_route" "hosts_ipv6" {
  route_table_id              = aws_route_table.hosts.id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "hosts" {
  subnet_id      = aws_subnet.hosts.id
  route_table_id = aws_route_table.hosts.id
}

resource "aws_route_table" "lb" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name      = "vespa-igw-rt"
    managedby = "vespa-cloud"
  }
}

resource "aws_route" "lb_default_ipv4" {
  route_table_id         = aws_route_table.lb.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route" "lb_default_ipv6" {
  route_table_id              = aws_route_table.lb.id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "lb" {
  subnet_id      = aws_subnet.lb.id
  route_table_id = aws_route_table.lb.id
}

# Network ACLs

resource "aws_network_acl" "main" {
  vpc_id = aws_vpc.main.id
  subnet_ids = [
    aws_subnet.hosts.id,
    aws_subnet.lb.id,
  ]
  tags = {
    Name      = "vespa-nacl"
    managedby = "vespa-cloud"
  }
}

resource "aws_network_acl_rule" "in_vpc_ipv4" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 100
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = aws_vpc.main.cidr_block
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "in_vpc_ipv6" {
  network_acl_id  = aws_network_acl.main.id
  rule_number     = 110
  protocol        = "-1"
  rule_action     = "allow"
  ipv6_cidr_block = aws_vpc.main.ipv6_cidr_block
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

# Security groups

resource "aws_security_group" "sg" {
  name        = "${var.zone.name}-sg-hostedvpc"
  description = "Vespa security group"
  vpc_id      = aws_vpc.main.id
  tags = {
    Name      = "vespa-vpc-sg"
    managedby = "vespa-cloud"
  }
}

resource "aws_security_group_rule" "in_vpc" {
  security_group_id = aws_security_group.sg.id
  type              = "ingress"
  description       = ""
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [aws_vpc.main.cidr_block]
  ipv6_cidr_blocks  = [aws_vpc.main.ipv6_cidr_block]
}

resource "aws_security_group_rule" "out_any" {
  security_group_id = aws_security_group.sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
}

# VPC endpoints

data "aws_region" "current" {}

resource "aws_vpc_endpoint" "interface" {
  for_each            = toset(["ecr.api", "ecr.dkr", "ssm", "ssmmessages", "ec2messages", "sts"])
  vpc_id              = aws_vpc.main.id
  subnet_ids          = [aws_subnet.hosts.id]
  security_group_ids  = [aws_security_group.sg.id]
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  tags = {
    Name      = "vespa-${replace(each.key, ".", "-")}-${var.zone.name}"
    managedby = "vespa-cloud"
  }
  # This has an interface in a subnet. If the subnet used by this is replaced,
  # we also have to replace this
  lifecycle {
    replace_triggered_by = [aws_subnet.hosts.id]
  }
}

resource "aws_vpc_endpoint" "ecr_s3" {
  vpc_id            = aws_vpc.main.id
  route_table_ids   = [aws_route_table.hosts.id]
  vpc_endpoint_type = "Gateway"
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  tags = {
    Name      = "vespa-s3gw-${var.zone.name}"
    managedby = "vespa-cloud"
  }
}

# EBS encryption key

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "ebs_key" {
  policy_id = "key-default-1"

  statement {
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    #checkov:skip=CKV_AWS_109:This is a key policy. Resource must be '*'
    #checkov:skip=CKV_AWS_111:This is a key policy. Resource must be '*'
    resources = [ "*" ]
  }

  statement {
    effect = "Allow"

    actions = [
      "kms:CreateGrant"
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = [true]
    }

    #checkov:skip=CKV_AWS_109:This is a key policy. Resource must be '*'
    #checkov:skip=CKV_AWS_111:This is a key policy. Resource must be '*'
    resources = [ "*" ]
  }

  statement {
    effect = "Allow"

    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion"
    ]

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.arn]
    }

    #checkov:skip=CKV_AWS_109:This is a key policy. Resource must be '*'
    #checkov:skip=CKV_AWS_111:This is a key policy. Resource must be '*'
    resources = [ "*" ]
  }
}

resource "aws_kms_key" "ebs" {
  description             = "Key used for EBS encryption on Vespa instances"
  key_usage               = "ENCRYPT_DECRYPT"
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.ebs_key.json
  deletion_window_in_days = 7
  tags = var.zone.is_cd ? {
    managedby          = "vespa-cloud"
    "eh:DeleteConsent" = "Integration test"
    } : {
    managedby = "vespa-cloud"
  }
}

resource "aws_kms_alias" "ebs" {
  name          = "alias/vespa-ebs-key-${var.zone.environment}-${var.zone.region}"
  target_key_id = aws_kms_key.ebs.key_id
}
