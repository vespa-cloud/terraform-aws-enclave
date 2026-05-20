
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

variable "is_multi_az" {
  description = "Set to true only when this module is invoked as a child of modules/zone_multi_az. When true, this module skips the resources the wrapper owns instead (NACL, NAT gateway + EIP, hosts route table, S3 gateway endpoint). Single-AZ callers leave this unset."
  type        = bool
  default     = false
  nullable    = false
}

variable "extra_ingress_cidr_blocks" {
  description = "Additional IPv4 CIDR blocks to allow on the zone security group's ingress rule, alongside the VPC's primary CIDR. Used by modules/zone_multi_az to extend ingress to secondary-AZ CIDRs. Leave empty for single-AZ."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "extra_ingress_ipv6_cidr_blocks" {
  description = "Additional IPv6 CIDR blocks to allow on the zone security group's ingress rule, alongside the VPC's primary IPv6 CIDR. Used by modules/zone_multi_az to extend ingress to secondary-AZ IPv6 CIDRs. Leave empty for single-AZ."
  type        = list(string)
  default     = []
  nullable    = false
}
