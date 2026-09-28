# Frozen resource graph from modules/coredump-access in v1.10.0.
# This fixture is migration-test input, not a supported module.

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

locals {
  debug_account_id = split(":", var.debug_instance_role_arn)[4]
  enabled          = var.read_access_expires_at == null ? 0 : 1
}

resource "aws_iam_role" "coredump_read" {
  count       = local.enabled
  name        = "vespa-coredump-read"
  description = "Allows Vespa Cloud debug instances time-limited read access to core dump buckets"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          AWS = "arn:aws:iam::${local.debug_account_id}:root"
        }
        Condition = {
          ArnEquals = {
            "aws:PrincipalArn" = var.debug_instance_role_arn
          }
          DateLessThan = {
            "aws:CurrentTime" = var.read_access_expires_at
          }
        }
      }
    ]
  })
  tags = {
    managedby = "vespa-cloud"
  }
}

resource "aws_iam_role_policy_attachment" "coredump_read" {
  count      = local.enabled
  role       = aws_iam_role.coredump_read[0].name
  policy_arn = aws_iam_policy.coredump_read[0].arn
}

resource "aws_iam_policy" "coredump_read" {
  #checkov:skip=CKV_AWS_356:KMS statement requires Resource '*', constrained by alias and ViaService conditions
  count = local.enabled
  name  = "vespa-coredump-read-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadCoredumpBuckets"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
        ]
        Resource = [
          "arn:aws:s3:::vespa-coredump-*",
        ]
        Condition = {
          DateLessThan = {
            "aws:CurrentTime" = var.read_access_expires_at
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "kms:ViaService" = "s3.*.amazonaws.com"
          }
          "ForAnyValue:StringLike" = {
            "kms:ResourceAliases" = "alias/vespa-coredump-key-*"
          }
          DateLessThan = {
            "aws:CurrentTime" = var.read_access_expires_at
          }
        }
      }
    ]
  })
  tags = {
    managedby = "vespa-cloud"
  }
}
