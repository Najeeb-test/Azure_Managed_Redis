# =============================================================================
# RESOURCE IDENTIFIERS
# =============================================================================

output "redis_cache_id" {
  description = "The resource ID of the Azure Redis Cache instance."
  value       = azurerm_redis_cache.main.id
}

output "redis_cache_name" {
  description = "The name of the Azure Redis Cache instance."
  value       = azurerm_redis_cache.main.name
}

output "redis_cache_hostname" {
  description = "The hostname of the Redis Cache instance."
  value       = azurerm_redis_cache.main.hostname
}

output "redis_cache_ssl_port" {
  description = "The SSL port of the Redis Cache (6380)."
  value       = azurerm_redis_cache.main.ssl_port
}

output "redis_cache_port" {
  description = "The non-SSL port of the Redis Cache (6379). Only available if enabled."
  value       = azurerm_redis_cache.main.port
}

# =============================================================================
# SENSITIVE OUTPUTS (CREDENTIALS)
# =============================================================================

output "redis_primary_access_key" {
  description = "The primary access key for the Redis Cache. SENSITIVE."
  value       = azurerm_redis_cache.main.primary_access_key
  sensitive   = true
}

output "redis_secondary_access_key" {
  description = "The secondary access key for the Redis Cache. SENSITIVE."
  value       = azurerm_redis_cache.main.secondary_access_key
  sensitive   = true
}

output "redis_primary_connection_string" {
  description = "The primary connection string for the Redis Cache. SENSITIVE."
  value       = azurerm_redis_cache.main.primary_connection_string
  sensitive   = true
}

output "redis_secondary_connection_string" {
  description = "The secondary connection string for the Redis Cache. SENSITIVE."
  value       = azurerm_redis_cache.main.secondary_connection_string
  sensitive   = true
}

# =============================================================================
# NETWORK CONFIGURATION OUTPUTS
# =============================================================================

output "redis_private_static_ip_address" {
  description = "The static private IP address of the Redis Cache (VNet injection)."
  value       = azurerm_redis_cache.main.private_static_ip_address
}

output "private_endpoint_id" {
  description = "The resource ID of the private endpoint (if configured)."
  value       = var.private_endpoint.enabled ? azurerm_private_endpoint.redis[0].id : null
}
