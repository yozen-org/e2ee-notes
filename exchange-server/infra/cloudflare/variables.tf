variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string

  validation {
    condition     = length(var.cloudflare_account_id) == 32
    error_message = "cloudflare_account_id must be a 32-character Cloudflare ID."
  }
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for yozen.org"
  type        = string

  validation {
    condition     = length(var.cloudflare_zone_id) == 32
    error_message = "cloudflare_zone_id must be a 32-character Cloudflare ID."
  }
}

variable "zone_name" {
  description = "Cloudflare DNS zone name"
  type        = string
  default     = "yozen.org"

  validation {
    condition     = var.zone_name == "yozen.org"
    error_message = "This stack is intentionally scoped to yozen.org."
  }
}
