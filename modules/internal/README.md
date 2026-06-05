# Internal modules

The modules under `modules/internal/` are implementation details shared by
[`modules/zone`](../zone) and [`modules/zone_multi_az`](../zone_multi_az). They
are **not** part of the public interface of this Terraform module and must not
be consumed directly.

- `regional`: VPC-wide (regional) resources. The VPC, internet and NAT
  gateways, route tables, security group, KMS keys, S3 backup and archive
  buckets, and the S3 gateway VPC endpoint.
- `zonal`: per-AZ resources. The subnets (hosts, lb, natgw), route-table
  associations, the network ACL, and the interface VPC endpoints.

Their inputs, outputs, and resource addresses may change between releases
without a major version bump. Use [`modules/zone`](../zone) for single-AZ zones
or [`modules/zone_multi_az`](../zone_multi_az) for multi-AZ zones instead.
