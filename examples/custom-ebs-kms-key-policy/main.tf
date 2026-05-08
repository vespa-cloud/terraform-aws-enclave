
#
# Set up the AWS Terraform Provider to point to the region where
# you want to provision the Vespa Cloud Enclave.
#
provider "aws" {
  region = "us-east-1"
}

#
# Set up the basic module that grants Vespa Cloud permission to
# provision Vespa Cloud resources inside the AWS account.
#
module "enclave" {
  source      = "vespa-cloud/enclave/aws"
  version     = ">= 1.0.0, < 2.0.0"
  tenant_name = "<YOUR-TENANT-HERE>"
}

#
# Define a custom EBS KMS key policy to grant an external principal access
# to the key. A common use case is agentless security scanning, where a role
# in a separate scanner account needs read access to encrypted EBS volumes.
#
data "aws_iam_policy_document" "ebs_kms_key_extra" {
  statement {
    sid    = "AllowAgentlessScanner"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::<SCANNER-ACCOUNT-ID>:role/<SCANNER-ROLE-NAME>"]
    }
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKeyWithoutPlaintext",
      "kms:ReEncrypt*",
    ]
    resources = ["*"]
  }
}

#
# Set up the VPC that will contain the Enclaved Vespa application for the dev environment.
# The custom_ebs_kms_key_policy extends the EBS encryption key policy to allow the
# external scanner role defined above to access encrypted volumes.
#
module "zone_dev_us_east_1c" {
  source  = "vespa-cloud/enclave/aws//modules/zone"
  version = ">= 1.0.0, < 2.0.0"
  zone    = module.enclave.zones.dev.aws_us_east_1c

  custom_ebs_kms_key_policy = data.aws_iam_policy_document.ebs_kms_key_extra.json
}
