# Plan-only smoke test with a mocked AWS provider. Runs without credentials.
#
# Catches plan-time regressions: broken variable wiring, for_each/count
# errors, type mismatches, invalid references between the root module and
# the customer-facing submodules.

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

# Inputs for the runs that plan modules/internal/regional on its own. Each of
# those runs sets the zone object itself.
variables {
  azs                     = ["use1-az6"]
  primary_ipv4_cidr       = "10.128.0.0/16"
  primary_natgw_subnet_id = "subnet-00000000000000000"
}

# Plan the root module on its own, with only the required variable set.
run "root_module" {
  command = plan

  variables {
    tenant_name = "smoke"
  }

  assert {
    condition     = output.vespa_cloud_account == "332934501266"
    error_message = "unexpected default vespa_cloud_account"
  }

  assert {
    condition     = output.zones.prod.aws_us_east_1c.az == "use1-az6"
    error_message = "prod.aws-us-east-1c should map to use1-az6"
  }

  assert {
    condition     = length(output.zones.prod.aws_us_east_1.configserver_az) >= 2
    error_message = "multi-AZ zone should carry multiple configserver AZs"
  }

  assert {
    condition     = output.zones.prod.aws_us_east_1c.enclave_release == trimspace(file("VERSION")) && output.zones.prod.aws_us_east_1.enclave_release == trimspace(file("VERSION"))
    error_message = "every zone object should carry the release from the VERSION file"
  }

  assert {
    condition     = !can(output.zones.prod.aws_us_east_1c.template_version)
    error_message = "zone objects must not carry template_version, so that zone modules without the release check reject them"
  }

  assert {
    condition     = output.support_data_read_role_arn == null && output.support_data_read_trusted_principal_arn == null
    error_message = "omitting support_data_access_allowed_until should create no support-data access role"
  }
}

run "root_access_production" {
  command = apply

  variables {
    tenant_name                       = "acme"
    support_data_access_allowed_until = "2028-01-01T00:00:00Z"
  }

  assert {
    condition     = output.support_data_read_trusted_principal_arn == "arn:aws:iam::061361823659:role/vespa-debug.acme"
    error_message = "production support-data access should trust the tenant-specific production role"
  }

  assert {
    condition     = output.support_data_read_role_arn != null
    error_message = "a non-null access deadline should create the support-data access role"
  }
}

run "root_access_revoked" {
  command = apply

  variables {
    tenant_name                       = "acme"
    support_data_access_allowed_until = null
  }

  assert {
    condition     = output.support_data_read_role_arn == null && output.support_data_read_trusted_principal_arn == null
    error_message = "revoking root consent should destroy the support-data access role"
  }
}

run "production_debug_identity_boundary" {
  command = plan

  # The existing provision module has a separate, tighter role-name limit.
  # Override it here to test only the approved debug identity boundary.
  override_module {
    target = module.provision
  }

  variables {
    tenant_name                       = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    support_data_access_allowed_until = "2028-01-01T00:00:00Z"
  }

  assert {
    condition     = output.support_data_read_trusted_principal_arn == "arn:aws:iam::061361823659:role/vespa-debug.aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    error_message = "production support-data access should support a 52-character tenant name"
  }
}

run "public_cd_debug_identity_boundary" {
  command = plan

  # The existing provision module has a separate, tighter role-name limit.
  # Override it here to test only the approved debug identity boundary.
  override_module {
    target = module.provision
  }

  variables {
    tenant_name                       = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    vespa_cloud_account               = "786426250597"
    support_data_access_allowed_until = "2028-01-01T00:00:00Z"
  }

  assert {
    condition     = output.support_data_read_trusted_principal_arn == "arn:aws:iam::061361823659:role/vespa-debug-cd.aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    error_message = "public CD support-data access should trust the tenant-specific public CD role"
  }

  assert {
    condition     = length(local.debug_identity_name) == 64
    error_message = "the longest supported public CD identity should fit the IAM role-name limit"
  }
}

run "unsupported_vespa_cloud_account" {
  command = plan

  variables {
    tenant_name         = "acme"
    vespa_cloud_account = "123456789012"
  }

  expect_failures = [
    var.vespa_cloud_account,
  ]
}

run "production_tenant_name_too_long_for_debug_role" {
  command = plan

  override_module {
    target = module.provision
  }

  variables {
    tenant_name                       = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    support_data_access_allowed_until = "2028-01-01T00:00:00Z"
  }

  expect_failures = [
    output.support_data_read_role_arn,
  ]
}

run "public_cd_tenant_name_too_long_for_debug_role" {
  command = plan

  override_module {
    target = module.provision
  }

  variables {
    tenant_name                       = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    vespa_cloud_account               = "786426250597"
    support_data_access_allowed_until = "2028-01-01T00:00:00Z"
  }

  expect_failures = [
    output.support_data_read_role_arn,
  ]
}

# Plan the full customer-shaped composition (root + zone + zone_multi_az +
# ssh + support-data access) against the local code.
run "full_composition" {
  command = plan

  module {
    source = "./tests/full"
  }

  assert {
    condition     = output.vespa_host_role == "vespa.tenant.vespa.aws-123456789012.tenant-host-service"
    error_message = "vespa_host_role not derived from caller identity as expected"
  }
}

# The zone modules must be installed at the same release as the enclave module
# that produced their zone object. The check lives in the regional module that
# both zone modules share; full_composition covers a matching release passed
# through each zone module.
run "package_release" {
  command = apply

  module {
    source = "./tests/package-release"
  }
}

run "regional_accepts_matching_enclave_release" {
  command = plan

  module {
    source = "./modules/internal/regional"
  }

  variables {
    zone = {
      environment     = "prod"
      region          = "aws-us-east-1c"
      name            = "prod.aws-us-east-1c"
      tag             = "prod.aws-use-1c"
      az              = "use1-az6"
      enclave_release = run.package_release.release
    }
  }

  assert {
    condition     = aws_vpc.main.tags.vespa_template_version == trimspace(file("VERSION"))
    error_message = "the VPC should be tagged with the release"
  }
}

run "regional_rejects_other_enclave_release" {
  command = plan

  module {
    source = "./modules/internal/regional"
  }

  variables {
    zone = {
      environment     = "prod"
      region          = "aws-us-east-1c"
      name            = "prod.aws-us-east-1c"
      tag             = "prod.aws-use-1c"
      az              = "use1-az6"
      enclave_release = "0.0.1"
    }
  }

  expect_failures = [
    terraform_data.validations,
  ]
}

# Enclave module releases before 3.0.0 emit template_version and no
# enclave_release. template_version must not satisfy the check, even when it
# equals the zone module's release.
run "regional_rejects_enclave_without_release" {
  command = plan

  module {
    source = "./modules/internal/regional"
  }

  variables {
    zone = {
      environment      = "prod"
      region           = "aws-us-east-1c"
      name             = "prod.aws-us-east-1c"
      tag              = "prod.aws-use-1c"
      az               = "use1-az6"
      template_version = run.package_release.release
    }
  }

  expect_failures = [
    terraform_data.validations,
  ]
}
