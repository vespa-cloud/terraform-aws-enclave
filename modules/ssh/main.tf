
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "vespa_ssh_login_role" {
  name        = "vespa-ssh-login"
  description = "Allows Vespa operators SSH access to instances"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${var.vespa_cloud_account}:role/vespa-enclave-ssh-login",
          ]
        }
      }
    ]
  })
  tags = {
    managedby = "vespa-cloud"
  }
}

resource "aws_iam_role_policy_attachment" "ssh_login" {
  role       = aws_iam_role.vespa_ssh_login_role.name
  policy_arn = aws_iam_policy.vespa_ssh_login_policy.arn
}

resource "aws_iam_policy" "vespa_ssh_login_policy" {
  name = "vespa-ssh-login-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:StartSession",
        ]
        Resource = [
          "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:instance/*",
          "arn:aws:ssm:*:${var.vespa_cloud_account}:document/Vespa-UpdatePublicSshKey",
          "arn:aws:ssm:*::document/AWS-StartSSHSession",
        ]
      },
      {
        Effect   = "Allow"
        Action   = "ssm:GetCommandInvocation"
        Resource = "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
  tags = {
    managedby = "vespa-cloud"
  }
}
