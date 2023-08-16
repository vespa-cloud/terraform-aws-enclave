
variable "zone" {
  description = "Vespa Cloud zone to bootstrap"
  type = object({
    environment = string,
    region      = string,
    name        = string,
    tag         = string,
    az          = string,
    is_cd       = bool,
  })
}

locals {
  valid_ipv4_subnets = tolist([for x in range(0, 256) : cidrsubnet("10.0.0.8/8", 8, x)])
}

variable "zone_ipv4_cidr" {
  description = "CIDR for zone network"
  type        = string
  default     = "10.128.0.0/16"
  validation {
    condition = try(cidrnetmask(var.zone_ipv4_cidr), null) == "255.255.0.0" && contains(locals.valid_ipv4_subnets, var.zone_ipv4_cidr)
    error_message = "CIDR for the zone network must be /16 and must be within 10.0.0.0/8"
  }
}
