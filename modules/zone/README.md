# Zone

In Vespa Cloud each deployment of a Vespa application goes into a [zone](https://cloud.vespa.ai/en/reference/zones).
Zones hosted on AWS are always contained within one [Availability Zone](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html#concepts-availability-zones) in AWS.

An Enclave VPC of Vespa Cloud must be located in the same Availability Zone as the configuration servers managing
that Enclave VPC.  This ensures that fail-over between Availability Zones can be maintained and reduces the risk
of down time on the Vespa application.

For each Enclave VPC that is needed, an instance of this module must be configured.

For this module to work the [top-level module](../../) must also be configured.

```
module "enclave" {
  source      = "vespa-cloud/enclave/aws"
  version     = ">= 1.0.0, < 2.0.0"
  tenant_name = "<vespa cloud tenant>"
}

module "zone_prod_us_east_1c" {
  source  = "vespa-cloud/enclave/aws//modules//zone"
  version = ">= 1.0.0, < 2.0.0"
  providers = {
    aws = aws.us_east_1
  }
}
```
