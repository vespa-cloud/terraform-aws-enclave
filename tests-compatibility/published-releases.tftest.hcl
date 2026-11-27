# Plans the modules from this checkout together with modules from a published
# release that predates the release check. Every pairing must fail to plan.
#
# The failures are in nested modules and in variable types, which
# expect_failures cannot refer to, so this run fails by design and check.sh
# inspects its output. Run it through that script.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:role/smoke-test"
    }
  }
  mock_data "aws_region" {
    defaults = {
      name = "us-east-1"
    }
  }
  mock_data "aws_availability_zone" {
    defaults = {
      name = "us-east-1a"
    }
  }
  mock_data "aws_iam_session_context" {
    defaults = {
      issuer_arn = "arn:aws:iam::123456789012:role/smoke-test"
    }
  }

  # Computed attributes that are parsed/validated at plan time need
  # plausible fake values instead of the auto-generated random strings.
  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::123456789012:policy/smoke-test"
    }
  }
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/smoke-test"
    }
  }
  mock_resource "aws_kms_key" {
    defaults = {
      arn = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
    }
  }
  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::smoke-test-bucket"
    }
  }
  mock_resource "aws_vpc" {
    defaults = {
      ipv6_cidr_block = "2600:1f18::/56"
    }
  }
  mock_resource "aws_vpc_ipv6_cidr_block_association" {
    defaults = {
      ipv6_cidr_block = "2600:1f18:100::/56"
    }
  }
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{}"
    }
  }
}

run "published_releases" {
  command = plan

  module {
    source = "./tests-compatibility/published-releases"
  }
}
