# Contract tests for the internal child module. These pin the IAM names,
# trusted principal, deadline, and unchanged storage scope used by the root.

mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/vespa-support-data-read"
    }
  }
  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::123456789012:policy/vespa-support-data-read-policy"
    }
  }
}

run "enabled_tenant_role" {
  command = plan

  module {
    source = "./modules/support-data-access"
  }

  variables {
    debug_instance_role_arn        = "arn:aws:iam::061361823659:role/vespa-debug-cd.vespa"
    support_data_access_expires_at = "2028-01-01T00:00:00Z"
  }

  assert {
    condition     = length(aws_iam_role.support_data_read) == 1 && length(aws_iam_policy.support_data_read) == 1 && length(aws_iam_role_policy_attachment.support_data_read) == 1
    error_message = "a deadline should create the role, policy, and attachment"
  }

  assert {
    condition     = aws_iam_role.support_data_read[0].name == "vespa-support-data-read" && aws_iam_policy.support_data_read[0].name == "vespa-support-data-read-policy"
    error_message = "support-data access should use the approved IAM names"
  }

  assert {
    condition     = length(jsondecode(aws_iam_role.support_data_read[0].assume_role_policy).Statement) == 1
    error_message = "the trust policy should contain exactly one statement"
  }

  assert {
    condition     = length(jsondecode(aws_iam_policy.support_data_read[0].policy).Statement) == 2
    error_message = "the permissions policy should contain exactly the approved S3 and KMS statements"
  }

  assert {
    condition     = jsondecode(aws_iam_role.support_data_read[0].assume_role_policy).Statement[0].Principal.AWS == "arn:aws:iam::061361823659:root"
    error_message = "the trust policy should name the debug account root"
  }

  assert {
    condition     = jsondecode(aws_iam_role.support_data_read[0].assume_role_policy).Statement[0].Action == "sts:AssumeRole"
    error_message = "the trust policy should allow only role assumption"
  }

  assert {
    condition     = jsondecode(aws_iam_role.support_data_read[0].assume_role_policy).Statement[0].Condition.ArnEquals["aws:PrincipalArn"] == "arn:aws:iam::061361823659:role/vespa-debug-cd.vespa"
    error_message = "the trust policy should require the selected tenant role"
  }

  assert {
    condition     = jsondecode(aws_iam_role.support_data_read[0].assume_role_policy).Statement[0].Condition.DateLessThan["aws:CurrentTime"] == "2028-01-01T00:00:00Z"
    error_message = "the trust policy should enforce the customer deadline"
  }

  assert {
    condition     = alltrue([for statement in jsondecode(aws_iam_policy.support_data_read[0].policy).Statement : statement.Condition.DateLessThan["aws:CurrentTime"] == "2028-01-01T00:00:00Z"])
    error_message = "the S3 and KMS permissions should enforce the customer deadline"
  }

  assert {
    condition     = jsondecode(aws_iam_policy.support_data_read[0].policy).Statement[0].Resource == ["arn:aws:s3:::vespa-coredump-*"]
    error_message = "the S3 permissions should remain scoped to core-dump buckets"
  }

  assert {
    condition     = jsondecode(aws_iam_policy.support_data_read[0].policy).Statement[0].Action == ["s3:GetObject", "s3:ListBucket", "s3:GetBucketLocation"]
    error_message = "the S3 policy should grant only the approved read actions"
  }

  assert {
    condition     = jsondecode(aws_iam_policy.support_data_read[0].policy).Statement[1].Condition["ForAnyValue:StringLike"]["kms:ResourceAliases"] == "alias/vespa-coredump-key-*"
    error_message = "the KMS permissions should remain scoped to core-dump key aliases"
  }

  assert {
    condition     = jsondecode(aws_iam_policy.support_data_read[0].policy).Statement[1].Action == ["kms:Decrypt", "kms:DescribeKey"]
    error_message = "the KMS policy should grant only the approved read actions"
  }
}

run "expired_deadline_keeps_resources" {
  command = plan

  module {
    source = "./modules/support-data-access"
  }

  variables {
    debug_instance_role_arn        = "arn:aws:iam::061361823659:role/vespa-debug.acme"
    support_data_access_expires_at = "2020-01-01T00:00:00Z"
  }

  assert {
    condition     = length(aws_iam_role.support_data_read) == 1 && length(aws_iam_policy.support_data_read) == 1 && length(aws_iam_role_policy_attachment.support_data_read) == 1
    error_message = "an expired deadline should retain the access resources"
  }

  assert {
    condition     = jsondecode(aws_iam_role.support_data_read[0].assume_role_policy).Statement[0].Condition.DateLessThan["aws:CurrentTime"] == "2020-01-01T00:00:00Z"
    error_message = "an expired deadline should remain in the trust policy for AWS to deny"
  }
}

run "disabled_access" {
  command = plan

  module {
    source = "./modules/support-data-access"
  }

  variables {
    debug_instance_role_arn        = "arn:aws:iam::061361823659:role/vespa-debug.acme"
    support_data_access_expires_at = null
  }

  assert {
    condition     = length(aws_iam_role.support_data_read) == 0 && length(aws_iam_policy.support_data_read) == 0 && length(aws_iam_role_policy_attachment.support_data_read) == 0
    error_message = "a null deadline should create no access resources"
  }
}

run "internal_module_requires_role_arn" {
  command = plan

  module {
    source = "./modules/support-data-access"
  }

  variables {
    debug_instance_role_arn        = null
    support_data_access_expires_at = "2028-01-01T00:00:00Z"
  }

  expect_failures = [
    var.debug_instance_role_arn,
  ]
}
