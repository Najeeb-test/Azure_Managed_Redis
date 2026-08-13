# =============================================================================
# AZURE REDIS CACHE - MAIN RESOURCE
# =============================================================================

resource "azurerm_redis_cache" "main" {
  name                = local.validated_name
  location            = var.location
  resource_group_name = var.resource_group_name

  # SKU Configuration
  sku_name = var.sku.name
  family   = var.sku.family
  capacity = var.sku.capacity

  # Redis Version
  redis_version = var.redis_version

  # Security Settings
  enable_non_ssl_port           = var.enable_non_ssl_port
  minimum_tls_version           = var.minimum_tls_version
  public_network_access_enabled = var.public_network_access_enabled

  # Authentication
  redis_configuration {
    enable_authentication           = var.enable_authentication
    maxmemory_policy                = var.redis_configuration.maxmemory_policy
    maxmemory_reserved              = var.redis_configuration.maxmemory_reserved
    maxfragmentationmemory_reserved = var.redis_configuration.maxfragmentationmemory_reserved
    notify_keyspace_events          = var.redis_configuration.notify_keyspace_events
    aof_backup_enabled              = var.redis_configuration.aof_backup_enabled

    # RDB Backup Configuration (Premium SKU only)
    rdb_backup_enabled            = local.is_rdb_backup_enabled ? var.rdb_backup_enabled : null
    rdb_backup_frequency          = local.is_rdb_backup_enabled ? var.rdb_backup_frequency : null
    rdb_backup_max_snapshot_count = local.is_rdb_backup_enabled ? var.rdb_backup_max_snapshot_count : null
    rdb_storage_connection_string = local.is_rdb_backup_enabled ? var.rdb_storage_connection_string : null
  }

  # High Availability - Clustering (Premium SKU only)
  shard_count = local.is_premium_sku ? var.shard_count : null

  # Zone Redundancy (Premium SKU only)
  zones = local.is_zone_redundant ? var.zones : null

  # Network Configuration - VNet Injection (Premium SKU only)
  subnet_id = local.is_premium_sku && local.is_vnet_injected ? var.subnet_id : null

  # Tags
  tags = local.common_tags

  # Lifecycle Rules
  lifecycle {
    # Prevent accidental deletion of production resources
    prevent_destroy = false # Set to true in production modules

    # Ignore changes to tags that might be managed externally
    ignore_changes = [
      tags["created_date"],
      tags["last_modified"]
    ]
  }
}

# =============================================================================
# PRIVATE ENDPOINT (OPTIONAL)
# =============================================================================

resource "azurerm_private_endpoint" "redis" {
  count = var.private_endpoint.enabled ? 1 : 0

  name                = "${local.validated_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint.subnet_id

  private_service_connection {
    name                           = "${local.validated_name}-psc"
    private_connection_resource_id = azurerm_redis_cache.main.id
    is_manual_connection           = false
    subresource_names              = ["redisCache"]
  }

  dynamic "private_dns_zone_group" {
    for_each = length(var.private_endpoint.private_dns_zone_ids) > 0 ? [1] : []
    content {
      name                 = "${local.validated_name}-dns-group"
      private_dns_zone_ids = var.private_endpoint.private_dns_zone_ids
    }
  }

  tags = local.common_tags
}

# =============================================================================
# DIAGNOSTIC SETTINGS (OPTIONAL)
# =============================================================================

resource "azurerm_monitor_diagnostic_setting" "redis" {
  count = var.diagnostic_settings.enabled ? 1 : 0

  name                           = "${local.validated_name}-diagnostics"
  target_resource_id             = azurerm_redis_cache.main.id
  log_analytics_workspace_id     = var.diagnostic_settings.log_analytics_workspace_id
  storage_account_id             = var.diagnostic_settings.storage_account_id
  eventhub_authorization_rule_id = var.diagnostic_settings.eventhub_authorization_rule_id

  # Logs
  dynamic "enabled_log" {
    for_each = var.diagnostic_settings.logs
    content {
      category = enabled_log.value.category

      retention_policy {
        enabled = enabled_log.value.retention_policy.enabled
        days    = enabled_log.value.retention_policy.days
      }
    }
  }

  # Metrics
  dynamic "metric" {
    for_each = var.diagnostic_settings.metrics
    content {
      category = metric.value.category
      enabled  = metric.value.enabled

      retention_policy {
        enabled = metric.value.retention_policy.enabled
        days    = metric.value.retention_policy.days
      }
    }
  }
}

# =============================================================================
# AZURE AD AUTHENTICATION (OPTIONAL - FUTURE ENHANCEMENT)
# =============================================================================

# Note: Azure AD authentication for Redis Cache is configured through
# azurerm_redis_cache_access_policy resource (requires Premium SKU)
# This is a placeholder for future implementation when var.aad_authentication_enabled is true

# resource "azurerm_redis_cache_access_policy" "aad" {
#   count = var.aad_authentication_enabled ? 1 : 0
#   
#   name             = "${local.validated_name}-aad-policy"
#   redis_cache_id   = azurerm_redis_cache.main.id
#   object_id        = data.azurerm_client_config.current.object_id
#   permissions      = "allkeys+get|set"
# }
