
variable "vpc_id" {
  type        = string
  description = "The VPC this archive should be available to"
}

variable "zone" {
  description = "Vespa Cloud zone to bootstrap"
  type = object({
    environment = string,
    region      = string,
    name        = string,
    az          = string,
    is_cd       = bool,
  })
}
