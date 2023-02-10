# SSH

An optional module to grant the Vespa Cloud operations team low-level
SSH access to the hosts inside the Enclave through [AWS SSM](https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-agent.html).

Only use this module if you explicitly wish to grant this access.

```terraform
module "enclave" {
    source = "../../Source/terraform-enclave-aws"
    tenant_name = "vespa"
}

module "ssh" {
    source              = "vespa-cloud/terraform-aws-vespa-cloud-enclave/modules/ssh"
    vespa_cloud_account = module.enclave.vespa_cloud_account
}
```