
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

locals {
  debug_account_id = split(":", var.debug_instance_role_arn)[4]
  # Grant access only when an expiry time is set. Unset (null) creates no
  # IAM resources, so customers can keep the module block present but inert.
  enabled = var.read_access_expires_at == null ? 0 : 1
}

# Role assumed by Vespa Cloud debug instances to read encrypted core dumps
# from the core dump buckets in this account. All access is automatically
# denied after the expiry time given in var.read_access_expires_at.
#
# The trust policy uses the debug account root as principal with an
# aws:PrincipalArn condition instead of naming the role directly. IAM
# validates named role principals on write, so a direct reference would
# break if the debug instance role does not exist yet, or is recreated.
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
      { # Allow S3 to decrypt core dump bucket objects (SSE-KMS) on read
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
