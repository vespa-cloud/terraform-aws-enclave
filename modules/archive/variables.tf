
variable "zone" {
  description = "Vespa Cloud zone to bootstrap"
  type = object({
    environment = string,
    region      = string,
    name        = string,
    tag         = string,
    az          = string,
  })
}

variable "archive_reader_principals" {
  description = "List of ARNs for principals allowed read access to Archive bucket objects"
  type        = list(string)
  default     = []
}
