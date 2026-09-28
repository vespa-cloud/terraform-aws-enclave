# Support-data read access

This internal module implements the time-limited IAM resources used by the root
Vespa Cloud Enclave module. Configure access through the root module's
`support_data_access_expires_at` input instead of instantiating this module
directly.

Set the root input only when you explicitly wish to grant Vespa Cloud support
temporary read access to encrypted heap dumps and native core dumps. Access is
read-only, limited to the existing core dump buckets, and automatically denied
after the expiry time. Extending access requires updating the timestamp and
re-applying.

The input is unset (`null`) by default, which creates no IAM resources and
grants no access.

Dump storage remains unchanged. Dumps are compressed and encrypted on the Vespa
host before they are written to the core dump bucket. The decryption key is held
by Vespa Cloud; this module grants access only to the encrypted bytes.

The root module derives the tenant-specific debug role ARN from its tenant and
Vespa Cloud account inputs. The child input `debug_instance_role_arn` is required
and is not part of the supported customer interface.
