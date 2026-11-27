# Vespa Cloud Enclave on AWS

This Terraform module bootstraps an AWS account with the IAM roles, policies and instance profiles
required to run Vespa Cloud Enclaves on AWS. It also exposes the set of supported Vespa Cloud zones
so you can create one or more Enclave networks using the provided zone submodule.

See Vespa Cloud documentation: https://cloud.vespa.ai/

## Module registries

[![Terraform Registry](https://img.shields.io/badge/Terraform%20Registry-vespa--cloud%2Fenclave%2Faws-623CE4?logo=terraform&logoColor=white)](https://registry.terraform.io/modules/vespa-cloud/enclave/aws)
[![OpenTofu Registry](https://img.shields.io/badge/OpenTofu%20Registry-vespa--cloud%2Fenclave%2Faws-FFDA18?logo=opentofu&logoColor=white)](https://search.opentofu.org/module/vespa-cloud/enclave/aws)

This module is published on both the Terraform and OpenTofu registries.

- Module address (both): `vespa-cloud/enclave/aws`
- Terraform Registry: https://registry.terraform.io/modules/vespa-cloud/enclave/aws
- OpenTofu Registry: https://search.opentofu.org/module/vespa-cloud/enclave/aws

## What this module sets up
- IAM roles for the Vespa Cloud provisioner and tenant hosts
- IAM policies granting the provisioner permission to manage EC2 instances, EBS volumes, load balancers, KMS keys and VPC endpoint services
- IAM policies for tenant hosts to upload to archive buckets and the existing `vespa-coredump-*` buckets used for memory dumps, access ECR container images and use SSM
- An instance profile for the tenant host service role

Networking (VPC, subnets, NAT gateway, security groups, VPC endpoints, KMS keys, S3 archive/backup buckets, and `vespa-coredump-*` memory-dump buckets)
is created per-zone via the `modules/zone` submodule after the root module has been applied.

## Requirements
- Terraform >= 1.7 or OpenTofu >= 1.7
- The examples declare the module version once and refer to it from every module block, which requires
  Terraform >= 1.15 or OpenTofu >= 1.8. See [Older Terraform and OpenTofu versions](#older-terraform-and-opentofu-versions)
  for the alternative.
- AWS provider (hashicorp/aws)
- AWS account where you have sufficient permissions to:
  - Create IAM roles, policies, and instance profiles
  - Create IAM role policy attachments

Authentication: configure the AWS provider using any supported auth method (CLI, environment variables,
IAM role, SSO). See https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration

## Usage
Since Vespa Cloud spans multiple AWS regions, you need one AWS provider per region. The root module
sets up global IAM resources, and each zone submodule creates region-specific networking.

Most zones live in a single Availability Zone and use the `modules/zone` submodule (shown below).
Zones that Vespa Cloud has designated as multi-AZ instead use the `modules/zone_multi_az` submodule;
see [`modules/zone_multi_az`](./modules/zone_multi_az) for details.

Production deployments in Vespa Cloud go through a CI/CD pipeline that requires `test` and
`staging` zones in addition to your `prod` zones. A `dev` zone is also typically set up for
manual development deployments. The example below sets up all four environments.

The enclave module and all its zone modules must be installed at the same release, so the example
declares the version once. See [Versioning](#versioning).

```hcl
# The release of the Vespa Cloud Enclave modules, used by every module block.
locals {
  enclave_version = "3.0.0"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"
}

# Bootstrap your account for Vespa Cloud
module "enclave" {
  source      = "vespa-cloud/enclave/aws"
  version     = local.enclave_version
  tenant_name = "<YOUR-VESPA-TENANT-NAME>"

  # Grant Vespa Cloud support limited-time read access to encrypted heap dumps
  # and native core dumps.
  # support_data_access_allowed_until = "2026-10-01T00:00:00Z"

  providers = {
    aws = aws.us_east_1
  }
}

# Dev zone for manual development deployments
module "zone_dev_us_east_1c" {
  source  = "vespa-cloud/enclave/aws//modules/zone"
  version = local.enclave_version
  zone    = module.enclave.zones.dev.aws_us_east_1c
  providers = {
    aws = aws.us_east_1
  }
}

# Test and staging zones are required by the Vespa Cloud CI/CD pipeline
# before changes can be promoted to prod.
module "zone_test_us_east_1c" {
  source  = "vespa-cloud/enclave/aws//modules/zone"
  version = local.enclave_version
  zone    = module.enclave.zones.test.aws_us_east_1c
  providers = {
    aws = aws.us_east_1
  }
}

module "zone_staging_us_east_1c" {
  source  = "vespa-cloud/enclave/aws//modules/zone"
  version = local.enclave_version
  zone    = module.enclave.zones.staging.aws_us_east_1c
  providers = {
    aws = aws.us_east_1
  }
}

# Production zones (add as many as you need)
module "zone_prod_us_east_1c" {
  source  = "vespa-cloud/enclave/aws//modules/zone"
  version = local.enclave_version
  zone    = module.enclave.zones.prod.aws_us_east_1c
  providers = {
    aws = aws.us_east_1
  }

  archive_reader_principals = [
    # The user or role ARN that is allowed to read the archive bucket for this zone
  ]
}

module "zone_prod_us_west_2a" {
  source  = "vespa-cloud/enclave/aws//modules/zone"
  version = local.enclave_version
  zone    = module.enclave.zones.prod.aws_us_west_2a
  providers = {
    aws = aws.us_west_2
  }

  archive_reader_principals = [
    # The user or role ARN that is allowed to read the archive bucket for this zone
  ]
}
```

See complete working examples in `examples/`.

## Inputs
- `tenant_name` (string, required): The Vespa Cloud tenant name that will operate in this account.
- `default_region` (string, optional, default `"us-east-1"`): Region to default to when resources don't need to be in a specific region.
- `vespa_cloud_account` (string, optional, defaults to the public production system): Vespa Cloud AWS account.
- `support_data_access_allowed_until` (string, optional, default `null`): RFC 3339 UTC timestamp until which Vespa Cloud may read encrypted heap dumps and native core dumps. Omitting it creates no access resources.

## Outputs
- `zones` (map): Map of available Vespa Cloud zones grouped by environment. Keys are referenced as
  `[environment].[region with - replaced by _]`, for example: `prod.aws_us_east_1c` or `dev.aws_us_east_1c`.
  Each zone object contains:
  - `name`: Full Vespa Cloud zone name (e.g. `prod.aws-us-east-1c`)
  - `region`: Vespa region id (e.g. `aws-us-east-1c`)
  - `az`: List of AWS Availability Zone IDs the zone spans (e.g. `["use1-az6"]`)
  - `configserver_az`: For multi-AZ zones, the AWS Availability Zone IDs the Vespa Cloud configservers run in (unset for single-AZ zones)
  - `enclave_release`: Release of the enclave module that produced the zone object. Each zone module requires it to equal its own release.

- `vespa_cloud_account` (string): The Vespa Cloud AWS account used to manage enclave accounts.

- `vespa_host_role` (string): The AWS role assigned to Vespa Cloud hosts.

- `support_data_read_role_arn` (string): ARN of the customer role that reads encrypted heap dumps and native core dumps, or `null` when access is disabled.

- `support_data_read_trusted_principal_arn` (string): ARN of the tenant-specific Vespa Cloud role trusted to read encrypted heap dumps and native core dumps, or `null` when access is disabled.

## Providers
- hashicorp/aws

## Resources created (high level)
- `aws_iam_role`: `vespa-cloud-provisioner`, tenant host service role, tenant host role
- `aws_iam_policy`: Provisioner policy (EC2, ELB, KMS), host policy (S3, ECR, KMS), host backup policy, backup expiry policy
- `aws_iam_role_policy_attachment`: Binds policies to roles, including `AmazonSSMManagedInstanceCore`
- `aws_iam_instance_profile`: For the tenant host service role

## Permissions needed by the Terraform runner
The principal running Terraform must be able to create IAM roles, policies, instance profiles and
role policy attachments.

Option A (simplest for bootstrap):
- `AdministratorAccess` on the account

Option B (least-privilege):
- `IAMFullAccess` or a custom policy allowing `iam:CreateRole`, `iam:CreatePolicy`, `iam:AttachRolePolicy`,
  `iam:CreateInstanceProfile`, `iam:AddRoleToInstanceProfile` and related read/list actions.
- For zone submodules: permissions to create VPCs, subnets, security groups, NAT gateways, KMS keys,
  S3 buckets, and VPC endpoints.

## Versioning
This module follows semantic versioning. Releases are listed at
https://github.com/vespa-cloud/terraform-aws-enclave/releases

The enclave module and all the zone modules that use its zone objects must be installed at the same
release. Each zone module checks this when planning. If its release differs from the enclave module's,
the plan fails with an error that names the zone and both releases:

```
Zone prod.aws-us-east-1c uses zone module release 3.0.0, but its zone object comes from enclave module
release 3.1.0. The enclave module and all of its zone modules must be installed at the same release.
Set every module block to the same version, 3.1.0 or newer, then run init -upgrade.
```

Declare the version once and refer to it from every module block, as the examples do:

```hcl
locals {
  enclave_version = "3.0.0"
}

module "enclave" {
  source  = "vespa-cloud/enclave/aws"
  version = local.enclave_version
  # ...
}

module "zone_prod_us_east_1c" {
  source  = "vespa-cloud/enclave/aws//modules/zone"
  version = local.enclave_version
  # ...
}
```

To upgrade, change that one value and run `terraform init -upgrade` or `tofu init -upgrade`.

Use an exact version, not a range such as `~> 3.0`. Terraform and OpenTofu choose a release for each
module block when that block is first installed. Blocks with the same range can therefore end up at
different releases, for example when you add a zone after a newer release has been published.

Two enclave modules in the same configuration may be at different releases, as long as each one's zone
modules match it.

### Older Terraform and OpenTofu versions

Referring to a local value in the `version` argument of a module block requires Terraform >= 1.15 or
OpenTofu >= 1.8. Older versions reject it:

```
Error: Variables not allowed

Variables may not be used here.
```

With an older version, write the same version as a literal in every module block instead:

```hcl
module "enclave" {
  source  = "vespa-cloud/enclave/aws"
  version = "3.0.0"
  # ...
}

module "zone_prod_us_east_1c" {
  source  = "vespa-cloud/enclave/aws//modules/zone"
  version = "3.0.0"
  # ...
}
```

### Upgrading to v3

Version 3 requires the enclave module and its zone modules to be at the same release, and renames one
attribute of the zone objects to enforce it.

Upgrade every module block of an enclave to the same v3 release in one change, then run
`terraform init -upgrade` or `tofu init -upgrade`. Before applying, review the plan. Coming from v2, the
only changes to AWS resources should be updates of the `vespa_template_version` tag on the VPC of each
zone.

If a module block is left at an earlier release, the plan fails:

- A zone module at a release before 3.0.0 rejects the zone object from a v3 enclave module because
  an attribute it requires is missing, for example with `attribute "template_version" is required`.
  Upgrade that zone module block to the enclave module's release.
- A v3 zone module rejects the zone object from an enclave module at a release before 3.0.0 with the
  error shown under [Versioning](#versioning). Upgrade the enclave module block.

The `zones` output no longer has a `template_version` attribute in each zone object. The release is now
in `enclave_release`.

The minimum versions stated under [Requirements](#requirements) are now Terraform 1.7 and OpenTofu 1.7.

If you are on v1, upgrade directly to v3. There is no need to apply v2 first. Follow
[Upgrading support-data access from v1](#upgrading-support-data-access-from-v1) in the same change.

### Upgrading support-data access from v1

Version 2 replaced the standalone `modules/coredump-access` module and its
`vespa-coredump-read` IAM resources. Read access to encrypted heap dumps and
native core dumps is configured through the root module's
`support_data_access_allowed_until` input, which creates the renamed
`vespa-support-data-read` IAM resources.

If your last apply of the standalone `coredump-access` module had
`read_access_expires_at` unset or `null`, your Terraform state contains no IAM
resources from it. Remove the module block when you upgrade. No other
migration is needed.

If your last apply used a non-null `read_access_expires_at`, including an
expired timestamp, your Terraform state contains IAM resources created by the
standalone module. In the same configuration change:

1. Remove the standalone `coredump-access` module block.
2. Upgrade the root module and its zone modules to v3, and set `support_data_access_allowed_until` to the desired deadline, or leave it `null` to revoke access.

Apply the combined change once. Terraform can remove the legacy IAM resources
and create the new resources in the same apply because their AWS names differ.
The old module path is not available in v2 or later.

Before applying, review the plan. The plan should remove the
`vespa-coredump-read` resources and create the `vespa-support-data-read`
resources, unless `support_data_access_allowed_until` is `null`, in which case
it should create no new access resources.

Since version 2, `vespa_cloud_account` is typed as a string and validated to be
a supported public-system account ID. Callers using another value must update
it before upgrading.

## Examples
- Basic: `./examples/basic`
- Multi-region: `./examples/multi-region`
- Multi-AZ: `./examples/multi-az`

## License
Apache-2.0. See LICENSE.
