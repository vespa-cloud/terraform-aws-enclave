# Archive

This module sets up a S3 bucket and associated policies for storing archives of
data from EC2 instances running Vespa Cloud. The content of the bucket will be
logs, core dumps, heap dumps, and profiling reports.

The content of the S3 bucket is not available outside the VPC it was created
for.

This module should not be used directly, but is referenced from the
[`zone`](../zone/) module.
