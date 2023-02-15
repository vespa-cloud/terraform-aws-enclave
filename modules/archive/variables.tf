
variable "vpc_id" {
  type        = string
  description = "The VPC this archive should be available to"
}

variable "zone_name" {
  description = "Vespa zone name"
  type        = string
}
