
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  bucket_resource_name = "backup-${data.aws_caller_identity.current.account_id}-*"
}

data "aws_iam_policy_document" "provision_policy" {
  #checkov:skip=CKV_AWS_107: "Ensure IAM policies does not allow credentials exposure"
  #checkov:skip=CKV_AWS_109: "Ensure IAM policies does not allow permissions management / resource exposure without constraints"
  #checkov:skip=CKV_AWS_111: "Ensure IAM policies does not allow write access without constraints"
  #checkov:skip=CKV_AWS_356: TODO - Make this policy stricter, but allow this change since it's just a reformat of an existing policy
  policy_id = "provision-policy"

  statement {
    actions = [
      "ec2:AttachVolume",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:DeleteVolume",
      "ec2:DetachVolume",
      "ec2:ModifyInstanceAttribute",
      "ec2:RunInstances",
      "ec2:TerminateInstances"
    ]
    resources = [
      "arn:aws:ec2:*:*:image/*",
      "arn:aws:ec2:*:*:instance/*",
      "arn:aws:ec2:*:*:network-interface/*",
      "arn:aws:ec2:*:*:security-group/*",
      "arn:aws:ec2:*::snapshot/*",
      "arn:aws:ec2:*:*:subnet/*",
      "arn:aws:ec2:*:*:volume/*",
      "arn:aws:iam::*:role/*"
    ]
    effect = "Allow"
  }

  statement {
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.vespa_cloud_tenant_host_service.arn]
    effect    = "Allow"
  }

  statement {
    actions = [
      "kms:CreateGrant",
      "kms:GenerateDataKeyWithoutPlaintext",
      "kms:ReEncryptFrom",
      "kms:ReEncryptTo",
      "kms:ListAliases",
      "kms:ListKeys",
    ]
    resources = [
      "arn:aws:kms:*:*:key/*",
    ]
    effect = "Allow"
  }

  statement {
    actions = [
      "elasticloadbalancing:*"
    ]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    actions = [
      "ec2:AssignPrivateIpAddresses",
      "ec2:CreateTags",
      "ec2:CreateVpcEndpointServiceConfiguration",
      "ec2:DeleteVpcEndpointServiceConfigurations",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeClassicLinkInstances",
      "ec2:DescribeCoipPools",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeInstances",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVolumes",
      "ec2:DescribeVpcClassicLink",
      "ec2:DescribeVpcEndpointConnections",
      "ec2:DescribeVpcEndpointServiceConfigurations",
      "ec2:DescribeVpcEndpointServicePermissions",
      "ec2:DescribeVpcPeeringConnections",
      "ec2:DescribeVpcs",
      "ec2:GetCoipPoolUsage",
      "ec2:ModifyVpcEndpointServiceConfiguration",
      "ec2:ModifyVpcEndpointServicePermissions",
      "ec2:StartInstances",
      "ec2:StartVpcEndpointServicePrivateDnsVerification",
    ]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    effect    = "Allow"
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["elasticloadbalancing.amazonaws.com"]
    }
  }
}

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
  tags = {
    managedby = "vespa-cloud"
  }
}

resource "aws_iam_role_policy_attachment" "provision" {
  role       = aws_iam_role.vespa_cloud_provisioner_role.name
  policy_arn = aws_iam_policy.vespa_cloud_provision_policy.arn
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.vespa_cloud_provisioner_role.name
  policy_arn = aws_iam_policy.vespa_cloud_backup_expiry_policy.arn
}

resource "aws_iam_policy" "vespa_cloud_provision_policy" {
  name   = "vespa-cloud-provisioner-policy"
  policy = data.aws_iam_policy_document.provision_policy.json
  tags = {
    managedby = "vespa-cloud"
  }
}

resource "aws_iam_policy" "vespa_cloud_host_policy" {
  #checkov:skip=CKV_AWS_290: Resource '*' is OK because we have a condition
  name = "vespa-cloud-host-policy"
  policy = jsonencode({
    Version = "2012-10-17",
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
        Effect   = "Allow"
        Action   = "kms:GenerateDataKey"
        Resource = "*"
        Condition = {
          StringLike = {
            "kms:ViaService" : "s3.*.amazonaws.com"
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

resource "aws_iam_policy" "vespa_cloud_host_backup_policy" {
  name = "vespa-cloud-host-backup-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "TenantHostAccess",
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ],
        # Snapshot content is stored under /snapshots/<hostname>/<uuid>/
        Resource = "arn:aws:s3:::${local.bucket_resource_name}/snapshots/*/*/*"
      },
      {
        Sid    = "TenantHostAccessList",
        Effect = "Allow",
        Action = [
          "s3:ListBucket"
        ],
        # Allow node to list files under the snapshot path:
        Condition = {
          "StringLike" : {
            "s3:prefix" : [
              "snapshots/*/*/",
              "snapshots/*/*/*"
            ]
          }
        }
        Resource = "arn:aws:s3:::${local.bucket_resource_name}"
      }
    ]
  })
}

resource "aws_iam_policy" "vespa_cloud_backup_expiry_policy" {
  name = "vespa-cloud-backup-expiry-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "ConfigServerAccess",
        Effect = "Allow",
        Action = [
          "s3:DeleteObject"
        ],
        Resource = "arn:aws:s3:::${local.bucket_resource_name}/*"
      },
      {
        Sid    = "ConfigServerAccessList",
        Effect = "Allow",
        Action = [
          "s3:ListBucket"
        ],
        Resource = "arn:aws:s3:::${local.bucket_resource_name}"
      }
    ]
  })
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
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.vespa_cloud_tenant_host_service.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "host" {
  role       = aws_iam_role.vespa_cloud_tenant_host_service.id
  policy_arn = aws_iam_policy.vespa_cloud_host_policy.arn
}

resource "aws_iam_role_policy_attachment" "host_backup" {
  role       = aws_iam_role.vespa_cloud_tenant_host_service.id
  policy_arn = aws_iam_policy.vespa_cloud_host_backup_policy.arn
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
