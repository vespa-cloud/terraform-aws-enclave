
variable "default_region" {
  description = "Region to default to when resources don't need to be in a specific region"
  type        = string
  default     = "us-east-1"
}

variable "tenant_name" {
  description = "The tenant owner running enclave account"
  type        = string
}

variable "vespa_cloud_account" {
  description = "The account the Vespa Cloud provisioner resides in"
  default     = "332934501266"
}

variable "all_zones" {
  description = "All AWS Vespa Cloud zones"
  type = list(object({
    environment = string
    region      = string
    tag         = string
  }))
  default = [
    { environment = "dev", region = "aws-us-east-1c", tag = "dev.aws-use-1c" },
    { environment = "test", region = "aws-us-east-1c", tag = "test.aws-use-1c" },
    { environment = "staging", region = "aws-us-east-1c", tag = "staging.aws-use-1c" },
    { environment = "perf", region = "aws-us-east-1c", tag = "perf.aws-use-1c" },
    { environment = "prod", region = "aws-us-east-1c", tag = "prod.aws-use-1c" },
    { environment = "prod", region = "aws-us-west-2a", tag = "prod.aws-usw-2a" },
    { environment = "prod", region = "aws-eu-west-1a", tag = "prod.aws-euw-1a" },
    { environment = "prod", region = "aws-ap-northeast-1a", tag = "prod.aws-apne-1a" },
  ]
}

variable "az_by_region" {
  description = "Mapping between Availability Zone and Availability Zone ID for the Vespa Cloud AWS zones"
  default = {
    aws-us-east-1c      = "use1-az6",
    aws-us-west-2a      = "usw2-az1",
    aws-eu-west-1a      = "euw1-az2",
    aws-ap-northeast-1a = "apne1-az4",
  }
}
