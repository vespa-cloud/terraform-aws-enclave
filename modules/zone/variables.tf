
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

variable "zone_ipv4_cidr" {
  description = "CIDR for zone network"
  type        = string
  default     = "10.128.0.0/16"
  validation {
    condition = try(cidrnetmask(var.zone_ipv4_cidr), null) == "255.255.0.0" && !contains(cidrsubnets("172.16.0.0/15", 1, 1), var.zone_ipv4_cidr)
    error_message = "CIDR for the zone network must be /16 and cannot overlap with 172.16.0.0/15"
  }
}
