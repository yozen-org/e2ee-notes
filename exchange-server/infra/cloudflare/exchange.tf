resource "cloudflare_worker" "exchange" {
  account_id = var.cloudflare_account_id
  name       = "e2ee-notes-exchange"

  subdomain = {
    enabled          = false
    previews_enabled = false
  }
}

resource "cloudflare_workers_kv_namespace" "objects" {
  account_id = var.cloudflare_account_id
  title      = "e2ee-notes-exchange-objects"
}

resource "cloudflare_workers_custom_domain" "exchange" {
  account_id = var.cloudflare_account_id
  zone_id    = var.cloudflare_zone_id
  zone_name  = var.zone_name
  hostname   = "e2eenotes.${var.zone_name}"
  service    = cloudflare_worker.exchange.name
}

output "kv_namespace_id" {
  description = "KV namespace ID (wrangler.jsonc の id に設定する)"
  value       = cloudflare_workers_kv_namespace.objects.id
}

output "worker_name" {
  description = "Cloudflare Worker name deployed by Wrangler"
  value       = cloudflare_worker.exchange.name
}

output "exchange_url" {
  description = "Public URL for the exchange Worker custom domain"
  value       = "https://${cloudflare_workers_custom_domain.exchange.hostname}"
}
