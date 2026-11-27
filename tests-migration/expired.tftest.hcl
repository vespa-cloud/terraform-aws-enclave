# Tests a v1-to-v3 upgrade with an expired access deadline. Expiry leaves the
# IAM resources in place; it restricts access through policy conditions. The
# first run creates the legacy resources and overrides module.enclave to
# exclude v3 resources. The second run replaces them with v3 support-data
# resources while preserving the expired deadline. Both runs use the same
# test module to share state. Each test file has its own isolated state.
#
# The upgrade goes directly from v1 to this checkout, without applying v2 in
# between.
#
# The mocked AWS provider updates test state without making AWS API calls.
# Live access and expiry enforcement require separate AWS tests.

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

run "expired_v1" {
  command = apply

  module {
    source = "./tests/upgrade"
  }

  override_module {
    target = module.enclave
    outputs = {
      support_data_read_role_arn              = null
      support_data_read_trusted_principal_arn = null
    }
  }

  variables {
    read_access_expires_at = "2020-01-01T00:00:00Z"
  }

  assert {
    condition = (
      output.legacy_role_arn != null &&
      output.legacy_role_name == "vespa-coredump-read" &&
      output.legacy_policy_name == "vespa-coredump-read-policy"
    )
    error_message = "the expired v1 state should retain the exact legacy IAM resources"
  }
}

run "expired_v3" {
  command = apply

  module {
    source = "./tests/upgrade"
  }

  variables {
    read_access_expires_at            = null
    support_data_access_allowed_until = "2020-01-01T00:00:00Z"
  }

  assert {
    condition     = output.support_data_role_arn != null
    error_message = "one v3 apply should replace expired legacy resources with v3 resources"
  }

  assert {
    condition = (
      output.legacy_role_arn == null &&
      output.legacy_role_name == null &&
      output.legacy_policy_name == null
    )
    error_message = "the v3 apply should remove the legacy IAM resources"
  }
}
