# Tests a v1-to-v2 upgrade with access disabled: both versions receive null
# for their access deadline. The first run overrides module.enclave to exclude
# v2 resources and verifies that no legacy access role or policy exists. The
# second run applies the v2 root module and verifies that access resources
# remain absent. Both runs use the same test module to share state. Each test
# file has its own isolated state.
#
# The mocked AWS provider updates test state without making AWS API calls.
# Live access enforcement requires separate AWS tests.

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

run "disabled_v1" {
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
    read_access_expires_at = null
  }

  assert {
    condition = (
      output.legacy_role_arn == null &&
      output.legacy_role_name == null &&
      output.legacy_policy_name == null
    )
    error_message = "the disabled v1 caller should contain no legacy IAM resources"
  }
}

run "disabled_v2" {
  command = apply

  module {
    source = "./tests/upgrade"
  }

  variables {
    read_access_expires_at            = null
    support_data_access_allowed_until = null
  }

  assert {
    condition = (
      output.legacy_role_arn == null &&
      output.legacy_role_name == null &&
      output.legacy_policy_name == null &&
      output.support_data_role_arn == null &&
      output.support_data_trusted_principal_arn == null
    )
    error_message = "a disabled caller should remain without access after the v2 upgrade"
  }
}
