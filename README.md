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
- IAM policies for tenant hosts to upload to archive buckets, access ECR container images and use SSM
- An instance profile for the tenant host service role

Networking (VPC, subnets, NAT gateway, security groups, VPC endpoints, KMS keys, S3 archive/backup buckets)
is created per-zone via the `modules/zone` submodule after the root module has been applied.

## Requirements
- Terraform >= 1.3 or OpenTofu >= 1.6
- AWS provider (hashicorp/aws)
- AWS account where you have sufficient permissions to:
  - Create IAM roles, policies, and instance profiles
  - Create IAM role policy attachments

Authentication: configure the AWS provider using any supported auth method (CLI, environment variables,
IAM role, SSO). See https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration

## Usage
Since Vespa Cloud spans multiple AWS regions, you need one AWS provider per region. The root module
sets up global IAM resources, and each zone submodule creates region-specific networking.

```hcl
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
  version     = ">= 1.0.0, < 2.0.0"
  tenant_name = "<YOUR-VESPA-TENANT-NAME>"
}

# Create one Vespa Cloud zone (VPC, subnets, NAT gateway, security groups, etc.)
module "zone_prod_us_east_1c" {
  source  = "vespa-cloud/enclave/aws//modules/zone"
  version = ">= 1.0.0, < 2.0.0"
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
  version = ">= 1.0.0, < 2.0.0"
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

## Outputs
- `zones` (map): Map of available Vespa Cloud zones grouped by environment. Keys are referenced as
  `[environment].[region with - replaced by _]`, for example: `prod.aws_us_east_1c` or `dev.aws_us_east_1c`.
  Each zone object contains:
  - `name`: Full Vespa Cloud zone name (e.g. `prod.aws-us-east-1c`)
  - `region`: Vespa region id (e.g. `aws-us-east-1c`)
  - `az`: AWS Availability Zone ID (e.g. `use1-az6`)
  - `template_version`: Module template version

- `vespa_cloud_account` (string): The Vespa Cloud AWS account used to manage enclave accounts.

- `vespa_host_role` (string): The AWS role assigned to Vespa Cloud hosts.

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
This module follows semantic versioning. Pin a compatible version range when consuming the module, for example:
`>= 1.0.0, < 2.0.0`.

## Examples
- Basic: `./examples/basic`
- Multi-region: `./examples/multi-region`

## License
Apache-2.0. See LICENSE.
