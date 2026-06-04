
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

module "archive" {
  source                    = "../archive"
  zone                      = var.zone
  archive_reader_principals = var.archive_reader_principals
}

resource "aws_vpc" "main" {
  cidr_block                       = var.primary_ipv4_cidr
  assign_generated_ipv6_cidr_block = true
  enable_dns_hostnames             = true
  tags = {
    Name                   = var.zone.tag # TODO Change to zone.name
    managedby              = "vespa-cloud"
    zone                   = var.zone.name
    archive_bucket         = module.archive.bucket
    vespa_template_version = var.zone.template_version
  }
}

resource "aws_vpc_ipv4_cidr_block_association" "secondary" {
  count      = length(var.secondary_ipv4_cidrs)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.secondary_ipv4_cidrs[count.index]
}

resource "aws_vpc_ipv6_cidr_block_association" "secondary" {
  count                            = length(var.secondary_ipv4_cidrs)
  vpc_id                           = aws_vpc.main.id
  assign_generated_ipv6_cidr_block = true
}

# Gateways

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name      = "${var.zone.name}-igw"
    managedby = "vespa-cloud"
  }
}

resource "aws_eip" "natgw" {
  count = length(var.azs)
  tags = {
    Name      = length(var.azs) == 1 ? "${var.zone.name}-eip-natgw" : "${var.zone.name}-eip-natgw-${var.azs[count.index]}"
    managedby = "vespa-cloud"
  }
}

# Single-AZ (legacy) NAT gateway: zonal, lives in one subnet.
resource "aws_nat_gateway" "gw" {
  count         = var.is_multi_az ? 0 : 1
  allocation_id = aws_eip.natgw[0].id
  subnet_id     = var.primary_natgw_subnet_id
  tags = {
    Name      = "${var.zone.name}-natgw"
    managedby = "vespa-cloud"
  }
  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}

# Multi-AZ Regional NAT gateway: a single gateway that spans AZs, with one EIP
# per AZ. availability_zone_address pins the EIPs so the gateway does not auto
# expand to AZs we have not provisioned.
resource "aws_nat_gateway" "regional" {
  count             = var.is_multi_az ? 1 : 0
  availability_mode = "regional"
  vpc_id            = aws_vpc.main.id

  dynamic "availability_zone_address" {
    for_each = var.azs
    content {
      availability_zone_id = availability_zone_address.value
      allocation_ids       = [aws_eip.natgw[availability_zone_address.key].id]
    }
  }

  tags = {
    Name      = "${var.zone.name}-natgw"
    managedby = "vespa-cloud"
  }
  depends_on = [aws_internet_gateway.gw]
}

# Routing tables

resource "aws_route_table" "hosts" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name      = "${var.zone.name}-rt"
    managedby = "vespa-cloud"
  }
}

resource "aws_route" "hosts_ipv4" {
  route_table_id         = aws_route_table.hosts.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.is_multi_az ? aws_nat_gateway.regional[0].id : aws_nat_gateway.gw[0].id
}

resource "aws_route" "hosts_ipv6" {
  route_table_id              = aws_route_table.hosts.id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.gw.id
}

resource "aws_route_table" "lb" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name      = "${var.zone.name}-igw-rt"
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

resource "aws_route_table" "natgw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name      = "${var.zone.name}-natgw-rt"
    managedby = "vespa-cloud"
  }
}

resource "aws_route" "natgw_ipv4" {
  route_table_id         = aws_route_table.natgw.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

# Security group

resource "aws_security_group" "sg" {
  name        = "${var.zone.name}-sg-hostedvpc"
  description = "Vespa security group"
  vpc_id      = aws_vpc.main.id
  tags = {
    Name      = "${var.zone.name}-vpc-sg"
    managedby = "vespa-cloud"
    zone      = var.zone.name
    service   = "hostedvpc"
  }
}

resource "aws_security_group_rule" "in_vpc" {
  security_group_id = aws_security_group.sg.id
  type              = "ingress"
  description       = ""
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = concat([aws_vpc.main.cidr_block], var.secondary_ipv4_cidrs)
  ipv6_cidr_blocks = concat(
    [aws_vpc.main.ipv6_cidr_block],
    aws_vpc_ipv6_cidr_block_association.secondary[*].ipv6_cidr_block,
  )
}

resource "aws_security_group_rule" "out_any" {
  # checkov:skip=CKV_AWS_382:Allow all traffic out of the VPC
  security_group_id = aws_security_group.sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
}

# VPC endpoints

resource "aws_vpc_endpoint" "ecr_s3" {
  vpc_id            = aws_vpc.main.id
  route_table_ids   = [aws_route_table.hosts.id]
  vpc_endpoint_type = "Gateway"
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  tags = {
    Name      = "vespa-s3gw-${var.zone.name}"
    managedby = "vespa-cloud"
    zone      = var.zone.name
    service   = "s3"
  }
}

# EBS encryption key

data "aws_iam_policy_document" "ebs_key_merged" {
  source_policy_documents = compact([
    data.aws_iam_policy_document.ebs_key.json,
    var.custom_ebs_kms_key_policy,
  ])
}

data "aws_iam_policy_document" "ebs_key" {
  policy_id = "key-default-1"

  statement {
    effect = "Allow"

    actions = [
      "kms:CancelKeyDeletion",
      "kms:Create*",
      "kms:Decrypt",
      "kms:Delete*",
      "kms:Describe*",
      "kms:Disable*",
      "kms:Enable*",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:Get*",
      "kms:List*",
      "kms:Put*",
      "kms:ReEncryptFrom",
      "kms:ReEncryptTo",
      "kms:Revoke*",
      "kms:ScheduleKeyDeletion",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:Update*",
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    #checkov:skip=CKV_AWS_109:This is a key policy. Resource must be '*'
    #checkov:skip=CKV_AWS_111:This is a key policy. Resource must be '*'
    #checkov:skip=CKV_AWS_356:This is a key policy. Resource must be '*'
    resources = ["*"]
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
    #checkov:skip=CKV_AWS_356:This is a key policy. Resource must be '*'
    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = ["kms:*"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_iam_session_context.current.issuer_arn]
    }

    #checkov:skip=CKV_AWS_109:This is a key policy. Resource must be '*'
    #checkov:skip=CKV_AWS_111:This is a key policy. Resource must be '*'
    #checkov:skip=CKV_AWS_356:This is a key policy. Resource must be '*'
    resources = ["*"]
  }
}

resource "aws_kms_key" "ebs" {
  description             = "Key used for EBS encryption on Vespa instances"
  key_usage               = "ENCRYPT_DECRYPT"
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.ebs_key_merged.json
  deletion_window_in_days = 7
  tags = {
    managedby = "vespa-cloud"
  }
}

resource "aws_kms_alias" "ebs" {
  name          = "alias/vespa-ebs-key-${var.zone.environment}-${var.zone.region}"
  target_key_id = aws_kms_key.ebs.key_id
}

# Backup storage

resource "aws_s3_bucket" "backup" {
  bucket = "backup-${data.aws_caller_identity.current.account_id}-${var.zone.environment}-${var.zone.region}"
}

resource "aws_s3_bucket_policy" "backup" {
  bucket = aws_s3_bucket.backup.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "RequiredSecureTransport",
        Effect    = "Deny",
        Principal = "*",
        Action    = "*",
        Resource  = "arn:aws:s3:::${aws_s3_bucket.backup.id}/*",
        Condition = {
          Bool = {
            "aws:SecureTransport" = false
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id
  rule {
    id     = "remove-incomplete"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 2
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backup" {
  bucket                  = aws_s3_bucket.backup.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.backup.arn
    }
  }
}

resource "aws_kms_key" "backup" {
  description         = "KMS key for backup bucket"
  enable_key_rotation = true
}

resource "aws_kms_alias" "backup" {
  name          = "alias/vespa-backup-key-${var.zone.environment}-${var.zone.region}"
  target_key_id = aws_kms_key.backup.key_id
}

resource "aws_kms_key_policy" "backup" {
  key_id = aws_kms_key.backup.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "Allow administration of the key",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
          ]
        },
        "Action" : [
          "kms:CancelKeyDeletion",
          "kms:Create*",
          "kms:Decrypt",
          "kms:Delete*",
          "kms:Describe*",
          "kms:Disable*",
          "kms:Enable*",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:Get*",
          "kms:List*",
          "kms:Put*",
          "kms:ReEncryptFrom",
          "kms:ReEncryptTo",
          "kms:Revoke*",
          "kms:ScheduleKeyDeletion",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:Update*",
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "Allow access through S3 for all principals in the account that are authorized to use S3",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : [
            "*"
          ]
        },
        "Action" : [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:CreateGrant",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "kms:CallerAccount" : data.aws_caller_identity.current.account_id
          },
          "StringLike" : {
            "kms:ViaService" : "s3.*.amazonaws.com"
          }
        }
      }
    ]
  })
}
