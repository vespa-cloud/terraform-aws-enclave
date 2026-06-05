# Core dump read access

An optional module to grant the Vespa Cloud operations team time-limited, read-only
access to the encrypted core dumps stored in this account's core dump buckets.

Only use this module when Vespa Cloud support has asked for access to a core dump,
and you explicitly wish to grant it. Access is read-only, limited to the core dump
buckets, and is automatically denied after the expiry time you set in
`read_access_expires_at`. Extending access requires updating the timestamp and
re-applying.

`read_access_expires_at` is unset (`null`) by default, which creates no IAM
resources and grants no access. You can keep the module block in your
configuration permanently and only set the timestamp when access is needed.

Core dumps are compressed and encrypted on the Vespa host before they are written
to the bucket. The decryption key is held by Vespa Cloud; this module only grants
access to the encrypted bytes.

Instantiate this module **once per account**, not per zone. It creates IAM
resources with fixed names, and the access it grants covers the core dump
buckets of all zones in the account.

```terraform
module "enclave" {
  source      = "vespa-cloud/enclave/aws"
  version     = ">= 1.0.0, < 2.0.0"
  tenant_name = "<vespa cloud tenant>"
}

module "coredump_access" {
  source                 = "vespa-cloud/enclave/aws//modules/coredump-access"
  version                = ">= 1.8.0, < 2.0.0"
  read_access_expires_at = "2026-07-01T00:00:00Z"
}
```

To revoke access before the expiry time, unset `read_access_expires_at` (or
remove the module) and apply.
