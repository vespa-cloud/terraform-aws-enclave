
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

data "aws_region" "current" {}

resource "aws_iam_role" "vespa_cloud_provisioner_role" {
  name        = "vespa-cloud-provisioner"
  description = "Allow config servers to provision resources"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.vespa_cloud_account}:role/vespa-cloud-provisioner"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  managed_policy_arns = [aws_iam_policy.vespa_cloud_provision_policy.arn]
  tags = {
    managedby = "vespa-cloud"
  }
}

resource "aws_iam_policy" "vespa_cloud_provision_policy" {
  name   = "vespa-cloud-provisioner-policy"
  policy = file("${path.module}/provisioner-policy.json")
  tags = {
    managedby = "vespa-cloud"
  }
}

resource "aws_iam_policy" "vespa_cloud_host_policy" {
  #checkov:skip=CKV_AWS_290: Resource '*' is OK because we have a condition
  name   = "vespa-cloud-host-policy"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      { # Allow hosts to upload to their archive bucket
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectTagging",
        ]
        Resource = "arn:aws:s3:::vespa-archive-*"
      },
      { # Allow hosts to generate data key to encrypt when uploading to archive bucket
        Effect    = "Allow"
        Action    = "kms:GenerateDataKey"
        Resource  = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService": "s3.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      },
      { # Allow getting ECR authorization token to download container images
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      { # Allow downloading container images from the system account
        Effect = "Allow"
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        Resource = "arn:aws:ecr:*:${var.vespa_cloud_account}:repository/*"
      }
    ]
  })
  tags = {
    managedby = "vespa-cloud"
  }
}

resource "aws_iam_role" "vespa_cloud_tenant_host_service" {
  name = "vespa.tenant.${var.tenant_name}.aws-${var.account}.tenant-host-service"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }
  })

  tags = {
    managedby = "vespa-cloud"
  }
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    aws_iam_policy.vespa_cloud_host_policy.arn
  ]
}

resource "aws_iam_role" "vespa_cloud_tenant_host_role" {
  name = "vespa.tenant.${var.tenant_name}.aws-${var.account}.tenant-host"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Effect = "Allow"
      Principal = {
        AWS = aws_iam_role.vespa_cloud_tenant_host_service.arn
      }
      Action = "sts:AssumeRole"
    }
  })
  tags = {
    managedby = "vespa-cloud"
  }
}

resource "aws_iam_instance_profile" "vespa_cloud_tenant_host_service" {
  name = aws_iam_role.vespa_cloud_tenant_host_service.name
  role = aws_iam_role.vespa_cloud_tenant_host_service.name
}
