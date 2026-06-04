
variable "zone" {
  description = "Vespa Cloud zone, used for resource tag names."
  type = object({
    environment      = string,
    region           = string,
    name             = string,
    tag              = string,
    az               = list(string),
    template_version = string,
  })
}

variable "azs" {
  description = "Ordered list of AWS AZ IDs. Primary AZ at index 0. Reordering after apply forces replacement of every resource indexed by count, so do not reorder."
  type        = list(string)
  validation {
    condition     = length(var.azs) >= 1
    error_message = "azs must contain at least one AZ ID."
  }
}

variable "vpc_id" {
  description = "VPC ID from modules/regional."
  type        = string
}

variable "security_group_id" {
  description = "Security group ID from modules/regional, attached to the interface VPC endpoints."
  type        = string
}

variable "ipv4_cidrs" {
  description = "IPv4 CIDR blocks aligned with var.azs. Index 0 is the primary VPC CIDR; indices 1+ are the secondary CIDR-block associations. Sourced from modules/regional outputs so the dependency on those resources is implicit."
  type        = list(string)
  validation {
    condition     = length(var.ipv4_cidrs) == length(var.azs)
    error_message = "ipv4_cidrs must have the same length as azs."
  }
}

variable "ipv6_cidr_blocks" {
  description = "IPv6 /56 CIDR blocks aligned with var.azs. Index 0 is the primary VPC IPv6 CIDR; indices 1+ are the secondary associations."
  type        = list(string)
  validation {
    condition     = length(var.ipv6_cidr_blocks) == length(var.azs)
    error_message = "ipv6_cidr_blocks must have the same length as azs."
  }
}

variable "hosts_route_table_id" {
  type = string
}

variable "lb_route_table_id" {
  type = string
}

variable "natgw_route_table_id" {
  type = string
}
