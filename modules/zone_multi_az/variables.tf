
variable "zone" {
  description = "Vespa Cloud zone to bootstrap. This module is for multi-AZ Vespa zones; zone.configserver_az must list at least 3 AZs (the AZs Vespa Cloud configservers run in). For single-AZ zones, use modules/zone instead."
  type = object({
    environment      = string,
    region           = string,
    name             = string,
    tag              = string,
    az               = list(string),
    configserver_az  = list(string),
    template_version = string,
  })
  validation {
    condition     = length(var.zone.configserver_az) >= 3
    error_message = "zone.configserver_az must contain at least 3 AWS AZ IDs. This module is for multi-AZ Vespa zones; configservers run in at least 3 AZs for HA. For single-AZ zones, use modules/zone instead."
  }
}

variable "azs" {
  description = "Additional AWS AZ IDs to deploy in this account, beyond the Vespa Cloud configserver AZs. The deployed AZs are the union of var.azs and var.zone.configserver_az; configserver AZs are always included so the enclave VPC can reach configservers. Leave null to deploy only in the configserver AZs."
  type        = list(string)
  default     = null
  nullable    = true
  validation {
    condition     = var.azs == null || length(coalesce(var.azs, [])) >= 1
    error_message = "azs must contain at least one AZ ID when set."
  }
}

variable "ipv4_cidr_base" {
  description = "Base /9 from which per-AZ /16 CIDRs are sliced. Override only if 10.128.0.0/9 would overlap an existing range in your AWS account."
  type        = string
  default     = "10.128.0.0/9"
  validation {
    condition     = try(cidrnetmask(var.ipv4_cidr_base), null) == "255.128.0.0"
    error_message = "ipv4_cidr_base must be a /9 CIDR."
  }
}

variable "primary_zone_az" {
  description = "AZ ID owning the VPC's primary CIDR block. Required when azs has more than one entry; optional (defaults to the single AZ) otherwise. Must be a member of azs. Changing this after apply forces VPC and subnet replacement, so pick it deliberately and do not change it later."
  type        = string
  default     = null
  nullable    = true
}

variable "archive_reader_principals" {
  description = "List of ARNs for principals allowed read access to Archive bucket objects"
  type        = list(string)
  default     = []
}

variable "custom_ebs_kms_key_policy" {
  description = "Any custom ebs kms key policy required"
  type        = string
  default     = null
}
