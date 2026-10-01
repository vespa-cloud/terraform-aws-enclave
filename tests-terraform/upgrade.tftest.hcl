# Terraform-only because state_key is not supported by OpenTofu 1.12.6.
# Mocked applies verify Terraform state transitions and module wiring without
# contacting AWS. They do not verify IAM enforcement, propagation, STS, S3,
# KMS, credentials, or the live public CD cutover.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:role/upgrade-test"
    }
  }
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{}"
    }
  }
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock-role"
    }
  }
  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::123456789012:policy/mock-policy"
    }
  }
}

run "enabled_v1" {
  command   = apply
  state_key = "enabled"

  module {
    source = "./tests/upgrade-v1"
  }

  variables {
    read_access_expires_at = "2028-01-01T00:00:00Z"
  }

  assert {
    condition     = output.role_arn != null && output.role_name == "vespa-coredump-read" && output.policy_name == "vespa-coredump-read-policy"
    error_message = "the enabled v1 state should contain the exact legacy IAM resources"
  }
}

run "enabled_v2" {
  command   = apply
  state_key = "enabled"

  module {
    source = "./tests/upgrade-v2"
  }

  variables {
    support_data_access_allowed_until = "2028-01-01T00:00:00Z"
  }

  assert {
    condition     = output.role_arn != null
    error_message = "one v2 apply should replace enabled legacy access with support-data access"
  }

  assert {
    condition     = output.trusted_principal_arn == "arn:aws:iam::061361823659:role/vespa-debug-cd.vespa"
    error_message = "the v2 role should trust the public CD tenant identity"
  }
}

run "expired_v1" {
  command   = apply
  state_key = "expired"

  module {
    source = "./tests/upgrade-v1"
  }

  variables {
    read_access_expires_at = "2020-01-01T00:00:00Z"
  }

  assert {
    condition     = output.role_arn != null && output.role_name == "vespa-coredump-read" && output.policy_name == "vespa-coredump-read-policy"
    error_message = "the expired v1 state should retain the exact legacy IAM resources"
  }
}

run "expired_v2" {
  command   = apply
  state_key = "expired"

  module {
    source = "./tests/upgrade-v2"
  }

  variables {
    support_data_access_allowed_until = "2020-01-01T00:00:00Z"
  }

  assert {
    condition     = output.role_arn != null
    error_message = "one v2 apply should replace expired legacy resources with v2 resources"
  }
}

run "disabled_v1" {
  command   = apply
  state_key = "disabled"

  module {
    source = "./tests/upgrade-v1"
  }

  variables {
    read_access_expires_at = null
  }

  assert {
    condition     = output.role_arn == null && output.role_name == null && output.policy_name == null
    error_message = "the disabled v1 caller should contain no legacy IAM resources"
  }
}

run "disabled_v2" {
  command   = apply
  state_key = "disabled"

  module {
    source = "./tests/upgrade-v2"
  }

  variables {
    support_data_access_allowed_until = null
  }

  assert {
    condition     = output.role_arn == null && output.trusted_principal_arn == null
    error_message = "a disabled caller should remain without access after the v2 upgrade"
  }
}
