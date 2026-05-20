
variable "zone" {
  description = "Vespa Cloud zone to bootstrap. zone.az lists every AWS AZ ID this Vespa zone spans; must contain at least two entries (this module is for multi-AZ Vespa zones; use modules/zone for single-AZ)."
  type = object({
    environment      = string,
    region           = string,
    name             = string,
    tag              = string,
    az               = list(string),
    template_version = string,
  })
  validation {
    condition     = length(var.zone.az) > 1
    error_message = "zone.az must contain more than one AWS AZ ID. This module is for multi-AZ Vespa zones; for single-AZ zones, use modules/zone instead."
  }
}

variable "azs" {
  description = "AWS AZ IDs to deploy in this account. Defaults to var.zone.az (mirrors Vespa Cloud's deployment). Override to deploy in different AZs than Vespa Cloud; tenants may provision in AZs the Vespa region itself does not occupy."
  type        = list(string)
  default     = null
  nullable    = true
  validation {
    condition     = var.azs == null || length(coalesce(var.azs, [])) >= 1
    error_message = "azs must contain at least one AZ ID."
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
