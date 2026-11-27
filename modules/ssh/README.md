# SSH

An optional module to grant the Vespa Cloud operations team low-level SSH access
to the hosts inside the Enclave through
[AWS SSM](https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-agent.html).

Only use this module if you explicitly wish to grant this access.

```terraform
locals {
  enclave_version = "3.0.0"
}

module "enclave" {
  source      = "vespa-cloud/enclave/aws"
  version     = local.enclave_version
  tenant_name = "<vespa cloud tenant>"
}

module "ssh" {
  source              = "vespa-cloud/enclave/aws//modules/ssh"
  version             = local.enclave_version
  vespa_cloud_account = module.enclave.vespa_cloud_account
}
```
