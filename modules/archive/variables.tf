
variable "zone" {
  description = "Vespa Cloud zone to bootstrap"
  type = object({
    environment = string,
    region      = string,
    name        = string,
    full_name   = string,
    az          = string,
    is_cd       = bool,
  })
}
