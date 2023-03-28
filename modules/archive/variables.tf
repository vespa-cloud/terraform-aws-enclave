
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
