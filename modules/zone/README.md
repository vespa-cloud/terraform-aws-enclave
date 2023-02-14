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
    source = "../../Source/terraform-enclave-aws"
    tenant_name = "vespa"
}

module "zone_prod_us_east_1c" {
    source = "../../Source/terraform-enclave-aws/modules/zone"
    zone = module.enclave.zones.prod.aws_us_east_1c
    providers = {
        aws = aws.us_east_1
    }
}
```
