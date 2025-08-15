# Secrets

An optional module to create secrets accessible by Vespa Cloud hosts.
Only use this module if you need secrets for a custom agent/daemon service on your hosts.

```terraform
module "enclave" {
  source      = "vespa-cloud/enclave/aws"
  version     = ">= 1.0.0, < 2.0.0"
  tenant_name = "<vespa cloud tenant>"
}

module "secrets" {
  source              = "vespa-cloud/enclave/aws//modules/secrets"
  version             = ">= 1.0.0, < 2.0.0"
  account             = data.aws_caller_identity.current.account_id
  tenant_name         = "<vespa cloud tenant>"

  # Define secret ARNs that should be made available to Vespa hosts
  secret_arns = [
      "arn:aws:secretsmanager:us-east-1:123456789012:secret:MyExampleSecret-AbCdEf"
  ]

  # Optional
  # kms_key_arns = [ "arn:aws:kms:<region>:<account-id>:key/<key-id>" ]
}
```
