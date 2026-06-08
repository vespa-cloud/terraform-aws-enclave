
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

data "aws_caller_identity" "current" {}

resource "random_string" "coredump" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_s3_bucket" "coredump" {
  bucket = "vespa-coredump-${data.aws_caller_identity.current.account_id}-${var.zone.name}-${random_string.coredump.id}"
  tags = {
    managedby = "vespa-cloud"
    zone      = var.zone.name
  }
}

resource "aws_s3_bucket_ownership_controls" "coredump" {
  bucket = aws_s3_bucket.coredump.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "coredump" {
  bucket = aws_s3_bucket.coredump.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "coredump" {
  bucket = aws_s3_bucket.coredump.id
  rule {
    id     = "expiration-rule"
    status = "Enabled"
    expiration {
      days = 7
    }
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 2
    }
  }
}

resource "aws_s3_bucket_policy" "coredump" {
  bucket = aws_s3_bucket.coredump.id
  policy = data.aws_iam_policy_document.coredump.json
}

resource "aws_s3_bucket_public_access_block" "coredump" {
  bucket                  = aws_s3_bucket.coredump.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "coredump" {
  bucket = aws_s3_bucket.coredump.bucket
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.coredump.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_kms_key" "coredump" {
  #checkov:skip=CKV2_AWS_64:Key policy is defined in aws_kms_key_policy.coredump
  description             = "Encryption key for ${aws_s3_bucket.coredump.bucket} S3 bucket"
  key_usage               = "ENCRYPT_DECRYPT"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  tags = {
    managedby = "vespa-cloud"
  }
}

resource "aws_kms_alias" "coredump" {
  name          = "alias/vespa-coredump-key-${var.zone.environment}-${var.zone.region}"
  target_key_id = aws_kms_key.coredump.key_id
}

data "aws_iam_policy_document" "coredump" {
  #checkov:skip=CKV_AWS_109:Root account statement delegates to IAM, same pattern as the archive bucket
  #checkov:skip=CKV_AWS_111:Root account statement delegates to IAM, same pattern as the archive bucket
  statement {
    sid = "SecureTransportOnly"

    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      "arn:aws:s3:::${aws_s3_bucket.coredump.id}",
      "arn:aws:s3:::${aws_s3_bucket.coredump.id}/*",
    ]

    actions = ["s3:*"]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Defense-in-depth for RS12: only compressed+encrypted dumps (.zst.enc) and
  # metadata files (.json) can be written. Raw (unencrypted) core files are
  # rejected even if the upload-side filtering in host-admin fails.
  statement {
    sid = "EncryptedDumpsOnly"

    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    not_resources = [
      "arn:aws:s3:::${aws_s3_bucket.coredump.id}/*.zst.enc",
      "arn:aws:s3:::${aws_s3_bucket.coredump.id}/*.json",
    ]

    actions = ["s3:PutObject"]
  }

  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions = [
      "s3:*"
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.coredump.id}",
      "arn:aws:s3:::${aws_s3_bucket.coredump.id}/*",
    ]
  }
}

data "aws_iam_policy_document" "kms_coredump" {
  #checkov:skip=CKV_AWS_109:Root account statement delegates to IAM, same pattern as the archive bucket
  #checkov:skip=CKV_AWS_111:Root account statement delegates to IAM, same pattern as the archive bucket
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions = [
      "kms:*"
    ]
    resources = [
      aws_kms_key.coredump.arn
    ]
  }
}

resource "aws_kms_key_policy" "coredump" {
  key_id = aws_kms_key.coredump.id
  policy = data.aws_iam_policy_document.kms_coredump.json
}
