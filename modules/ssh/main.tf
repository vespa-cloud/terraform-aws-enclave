
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
  managed_policy_arns = [aws_iam_policy.vespa_ssh_login_policy.arn]
  tags = {
    managedby = "vespa-cloud"
  }
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
          "arn:aws:ssm:*::document/AWS-StartSSHSession",
          aws_ssm_document.update_public_ssh_key.arn,
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

resource "aws_ssm_document" "update_public_ssh_key" {
  name          = "Vespa-UpdatePublicSshKey"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2",
    description   = "Temporarily adds public SSH key to the instance",
    parameters = {
      lifetime = {
        type           = "String"
        description    = "Duration, in seconds, they public key stays on the instance before it is deleted"
        default        = "10"
        allowedPattern = "^[0-9]+$"
      }
      publicKey = {
        type           = "String"
        description    = "SSH public key"
        allowedPattern = "^[a-zA-Z0-9+/ @-]+$"
      }
      user = {
        type           = "String"
        description    = "SSH username"
        default        = "ec2-user"
        allowedPattern = "^[a-z0-9-]+$"
      }
      operator = {
        type           = "String"
        description    = "Name of the operator"
        allowedPattern = "^[a-z0-9-]+$"
      }
    }

    mainSteps = [
      {
        name   = "updatePublicSshKey"
        action = "aws:runShellScript"
        inputs = {
          runCommand = [
            "#!/bin/bash",
            "keysdir=/etc/ssh/authorized_keys.d/{{user}}",
            "keyfile=$keysdir/{{operator}}.$RANDOM.$$",
            "test -d $keysdir || install -d -o root -g root -m 755 $keysdir",
            "install -o root -g root -m 644 <(printf \"%s\\n\" \"{{publicKey}}\") $keyfile",
            "nohup bash -c \"sleep {{lifetime}}; rm -f $keyfile\" &> /dev/null &"
          ]
        }
      }
    ]
  })

  tags = {
    managedby = "vespa-cloud"
  }
}
