# SSH

An optional module to grant the Vespa Cloud operations team low-level SSH access
to the hosts inside the Enclave through
[AWS SSM](https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-agent.html).

Only use this module if you explicitly wish to grant this access.

```terraform
module "enclave" {
  source      = "vespa-cloud/enclave/aws"
  version     = ">= 1.0.0, < 2.0.0"
  tenant_name = "<vespa cloud tenant>"
}

module "ssh" {
  source              = "vespa-cloud/enclave/aws//modules/ssh"
  version             = ">= 1.0.0, < 2.0.0"
  vespa_cloud_account = module.enclave.vespa_cloud_account
}
```
