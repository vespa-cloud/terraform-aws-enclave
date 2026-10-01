# Stateful mocked applies verify that withdrawing customer consent removes all
# access resources. AWS authorization after removal remains a live-test concern.

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

run "enable_access" {
  command = apply

  module {
    source = "./modules/support-data-access"
  }

  variables {
    debug_instance_role_arn           = "arn:aws:iam::061361823659:role/vespa-debug.acme"
    support_data_access_allowed_until = "2028-01-01T00:00:00Z"
  }

  assert {
    condition     = output.role_arn != null
    error_message = "an enabled access window should create the customer role"
  }
}

run "disable_access" {
  command = apply

  module {
    source = "./modules/support-data-access"
  }

  variables {
    debug_instance_role_arn           = "arn:aws:iam::061361823659:role/vespa-debug.acme"
    support_data_access_allowed_until = null
  }

  assert {
    condition     = output.role_arn == null
    error_message = "revoking consent should destroy the customer access resources"
  }
}
