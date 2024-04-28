variable "domain" {
  type = object({
    zone   = string
    prefix = optional(string)
  })
}

variable "tags" {
  description = "Custom tags"
  type        = map(string)
  default     = {}
}