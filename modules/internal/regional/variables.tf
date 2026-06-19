
variable "zone" {
  description = "Vespa Cloud zone to bootstrap"
  type = object({
    environment      = string,
    region           = string,
    name             = string,
    tag              = string,
    az               = optional(string),
    template_version = string,
  })
}

variable "is_multi_az" {
  description = "Whether this regional module is part of a multi-AZ Vespa zone. Controls the NAT gateway shape: single-AZ NAT gateway when false, AWS Regional NAT gateway (availability_mode=regional) when true."
  type        = bool
  default     = false
  nullable    = false
}

variable "azs" {
  description = "Ordered list of AWS AZ IDs this zone deploys in. Primary AZ at index 0. Reordering the list after apply forces replacement of every per-AZ resource indexed by count, so do not reorder."
  type        = list(string)
  validation {
    condition     = length(var.azs) >= 1
    error_message = "azs must contain at least one AZ ID."
  }
}

variable "primary_ipv4_cidr" {
  description = "Primary /16 CIDR for the VPC."
  type        = string
}

variable "secondary_ipv4_cidrs" {
  description = "List of /16 CIDRs for secondary AZs, aligned with var.azs[1:]. Empty for single-AZ."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "primary_natgw_subnet_id" {
  description = "Subnet ID for the legacy single-AZ NAT gateway. Required when is_multi_az = false; unused otherwise."
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
