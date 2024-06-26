
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

data "aws_caller_identity" "current" {}

resource "random_string" "archive" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_s3_bucket" "archive" {
  bucket = "vespa-archive-${data.aws_caller_identity.current.account_id}-${var.zone.name}-${random_string.archive.id}"
  tags = {
    managedby = "vespa-cloud"
    zone      = var.zone.name
  }
}

resource "aws_s3_bucket_ownership_controls" "archive" {
  bucket = aws_s3_bucket.archive.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
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
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
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
  #checkov:skip=CKV2_AWS_64:TODO - Ignore new check until it can be fixed. Default key policy is fine.
  description             = "Encryption key for ${aws_s3_bucket.archive.bucket} S3 bucket"
  key_usage               = "ENCRYPT_DECRYPT"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  tags = {
    managedby = "vespa-cloud"
  }
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
}
