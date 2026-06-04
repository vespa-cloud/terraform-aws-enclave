
variable "zone" {
  description = "Vespa Cloud zone to bootstrap"
  type = object({
    environment      = string,
    region           = string,
    name             = string,
    tag              = string,
    az               = list(string),
    template_version = string,
  })
  validation {
    condition     = length(var.zone.az) == 1
    error_message = "modules/zone is single-AZ and requires zone.az to have exactly one element. For multi-AZ zones, use modules/zone_multi_az."
  }
}

variable "zone_ipv4_cidr" {
  description = "CIDR for zone network"
  type        = string
  default     = "10.128.0.0/16"
  validation {
    condition     = try(cidrnetmask(var.zone_ipv4_cidr), null) == "255.255.0.0" && contains(tolist([for x in range(0, 256) : cidrsubnet("10.0.0.8/8", 8, x)]), var.zone_ipv4_cidr)
    error_message = "CIDR for the zone network must be /16 and must be within 10.0.0.0/8"
  }
}

variable "zone_az" {
  description = "Override AWS AZ for Vespa Cloud zone (EXPERIMENTAL)"
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
  description = "Any custom ebs kms key policy required. This can be to grant account external roles access to the key for agentless scanning or similar. Pass the json output from a `aws_iam_policy_document` data resource as the value"
  type        = string
  default     = null
}
