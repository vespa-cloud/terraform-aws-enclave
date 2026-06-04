# Zone (multi-AZ)

In Vespa Cloud each deployment of a Vespa application goes into a
[zone](https://cloud.vespa.ai/en/reference/zones). Most AWS zones live in a
single
[Availability Zone](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html#concepts-availability-zones)
and are configured with the [`modules/zone`](../zone) submodule. Some Vespa
Cloud zones instead span multiple Availability Zones for higher availability;
those zones use this module.

A multi-AZ Enclave VPC must be able to reach the Vespa Cloud configuration
servers that manage it. Those configservers run across at least three AZs,
listed in `zone.configserver_az`. This module always deploys into the
configserver AZs, and optionally into any additional AZs you specify, so that
fail-over between Availability Zones is preserved.

Use this module only for zones that Vespa Cloud has designated as multi-AZ: the
`zone` object will carry a `configserver_az` list of at least three AWS AZ IDs.
For ordinary single-AZ zones, use [`modules/zone`](../zone) instead.

For this module to work the [top-level module](../../) must also be configured.

## Usage

```hcl
module "enclave" {
  source      = "vespa-cloud/enclave/aws"
  version     = ">= 1.0.0, < 2.0.0"
  tenant_name = "<YOUR-VESPA-TENANT-NAME>"
}

module "zone_prod_us_east_1" {
  source  = "vespa-cloud/enclave/aws//modules/zone_multi_az"
  version = ">= 1.0.0, < 2.0.0"
  zone    = module.enclave.zones.prod.aws_us_east_1

  # AZ that owns the VPC's primary CIDR block. Must be one of the deployed AZs.
  # This is immutable: changing it later forces VPC and subnet replacement.
  primary_zone_az = "use1-az2"

  # Optional: deploy into additional AZs beyond the configserver AZs.
  azs = ["use1-az2", "use1-az4"]

  providers = {
    aws = aws.us_east_1
  }

  archive_reader_principals = [
    # The user or role ARN that is allowed to read the archive bucket for this zone
  ]
}
```

## How the deployed AZs are chosen

The set of AZs the VPC spans is the union of:

- `zone.configserver_az`: the AZs Vespa Cloud configservers run in. Always
  included so the enclave VPC can reach the configservers. Provided by Vespa
  Cloud through the `zone` object.
- `var.azs`: any additional AZs you want to host in. Leave `null` to deploy only
  in the configserver AZs.

Each deployed AZ gets its own `/16` IPv4 CIDR sliced from `var.ipv4_cidr_base`,
plus a `/56` IPv6 block. The AZ named by `var.primary_zone_az` owns the VPC's
primary CIDR block.

## Inputs

- `zone` (object, required): The zone to bootstrap, taken from
  `module.enclave.zones.<environment>.<region>`. Must include a
  `configserver_az` list with at least three AWS AZ IDs.
- `primary_zone_az` (string, required for multi-AZ): AZ ID that owns the VPC's
  primary CIDR block. Must be one of the deployed AZs. Immutable after apply.
- `azs` (list(string), optional, default `null`): Additional AWS AZ IDs to
  deploy into, beyond the configserver AZs.
- `ipv4_cidr_base` (string, optional, default `"10.128.0.0/9"`): Base `/9` from
  which per-AZ `/16` CIDRs are sliced. Override only if the default would
  overlap an existing range in your AWS account.
- `archive_reader_principals` (list(string), optional, default `[]`): ARNs of
  principals allowed read access to the archive bucket objects.
- `custom_ebs_kms_key_policy` (string, optional, default `null`): Additional EBS
  KMS key policy JSON, for example to grant an external scanner access to
  encrypted volumes.

## Outputs

- `vpc_id`, `cidr_block`, `ipv6_cidr_block`: The Enclave VPC and its primary
  CIDR blocks.
- `security_group_id`, `network_acl_id`: VPC-wide security group and network ACL.
- `archive_bucket`: Name of the per-zone archive bucket.
- `nat_gateway_id`, `hosts_route_table_id`: The regional NAT gateway and the
  hosts route table.
- `primary_hosts_subnet_id`, `primary_lb_subnet_id`, `primary_natgw_subnet_id`:
  Subnet IDs in the primary AZ.
- `hosts_subnet_ids`, `lb_subnet_ids`, `natgw_subnet_ids`, `eip_ids`: Maps of AZ
  ID to the corresponding resource ID across all deployed AZs.
- `secondary_cidr_blocks`, `secondary_ipv6_cidr_blocks`: Maps of secondary AZ ID
  to its IPv4 / IPv6 CIDR.

## Providers

- hashicorp/aws
