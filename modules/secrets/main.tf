
locals {
  reader_role = "vespa.tenant.${var.tenant_name}.aws-${var.account}.tenant-host-service"
}

# Policy document defining read access to the specific secrets
data "aws_iam_policy_document" "read_secrets" {
  statement {
    sid    = "ReadSpecificSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]
    resources = var.secret_arns
  }

  dynamic "statement" {
    for_each = length(var.kms_key_arns) > 0 ? [1] : []
    content {
      sid       = "KmsDecryptForSecrets"
      effect    = "Allow"
      actions   = ["kms:Decrypt"]
      resources = var.kms_key_arns
    }
  }
}

# Read access policy
resource "aws_iam_policy" "read_secrets" {
  name        = "${local.reader_role}-read-secrets"
  description = "Read access to a set of secrets for Vespa host agents."
  policy      = data.aws_iam_policy_document.read_secrets.json
  tags = {
    managedby = "vespa-cloud"
  }
}

# Attachment to host role
resource "aws_iam_role_policy_attachment" "attachment" {
  role       = local.reader_role
  policy_arn = aws_iam_policy.read_secrets.arn
}
