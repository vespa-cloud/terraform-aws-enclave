
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

data "aws_caller_identity" "current" {}

resource "random_string" "archive" {
  length   = 6
  special  = false
  upper    = false
}

resource "aws_s3_bucket" "archive" {
  bucket = "vespa-archive-${data.aws_caller_identity.current.account_id}-${var.zone_name}-${random_string.archive.id}"
  tags = {
    managedby = "vespa-cloud"
    zone      = var.zone_name
  }
}

resource "aws_s3_bucket_acl" "archive" {
  bucket = aws_s3_bucket.archive.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "archive" {
  bucket = aws_s3_bucket.archive.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "archive" {
  bucket = aws_s3_bucket.archive.id
  rule {
    id     = "expiration-rule"
    status = "Enabled"
    expiration {
      days = 31
    }
  }
}

resource "aws_s3_bucket_policy" "secure_transport" {
  bucket = aws_s3_bucket.archive.id
  policy = data.aws_iam_policy_document.archive.json
}

resource "aws_s3_bucket_public_access_block" "archive" {
  bucket                  = aws_s3_bucket.archive.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "archive" {
  bucket = aws_s3_bucket.archive.bucket
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.archive.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_kms_key" "archive" {
  description         = "Encryption key for ${aws_s3_bucket.archive.bucket} S3 bucket"
  key_usage           = "ENCRYPT_DECRYPT"
  enable_key_rotation = true
}

data "aws_iam_policy_document" "archive" {
  statement {
    sid = "SecureTransportOnly"

    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      aws_s3_bucket.archive.arn,
      "${aws_s3_bucket.archive.arn}/*"
    ]

    actions = ["s3:*"]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid = "ArchiveAccess"

    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:PutObjectTagging"
    ]

    resources = [
      aws_s3_bucket.archive.arn,
      "${aws_s3_bucket.archive.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpce"
      values   = [var.vpc_id]
    }
  }
}
