# =============================================================================
# LOCAL VALUES FOR NAMING AND VALIDATION
# =============================================================================

locals {
  # Construct full Redis Cache name following hierarchical convention
  # Format: <resource_prefix>-redis-<redis_name>
  # Example: contoso-prod-eastus-banking-redis-cache-001
  redis_cache_name = "${var.resource_prefix}-redis-${var.redis_name}"

  # Validation: ensure name meets Azure Redis Cache constraints
  # - Must be globally unique
  # - 1-63 characters
  # - Lowercase letters, numbers, and hyphens only
  # - Cannot start or end with hyphen
  validated_name = (
    length(local.redis_cache_name) >= 1 &&
    length(local.redis_cache_name) <= 63 &&
    can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", local.redis_cache_name))
  ) ? local.redis_cache_name : null

  # Merge common tags with environment-specific tags
  common_tags = merge(
    var.tags,
    {
      environment      = var.environment
      managed_by       = "terraform"
      module_name      = "azure-redis-cache"
      module_version   = "1.0.0"
      terraform_module = "true"
    }
  )

  # Determine if Premium SKU is being used (required for certain features)
  is_premium_sku = var.sku.name == "Premium"

  # Determine if clustering is enabled
  is_clustered = local.is_premium_sku && var.shard_count != null && var.shard_count > 0

  # Determine if zone redundancy is enabled
  is_zone_redundant = local.is_premium_sku && length(var.zones) > 0

  # Determine if VNet injection is configured
  is_vnet_injected = var.subnet_id != null

  # Determine if private endpoint is configured
  is_private_endpoint_enabled = var.private_endpoint.enabled

  # Determine if diagnostics are enabled
  is_diagnostics_enabled = var.diagnostic_settings.enabled

  # Determine if RDB backup is enabled (Premium only)
  is_rdb_backup_enabled = local.is_premium_sku && var.rdb_backup_enabled

  # Redis configuration dynamic block preparation
  redis_config = {
    maxmemory_policy                = var.redis_configuration.maxmemory_policy
    maxmemory_reserved              = var.redis_configuration.maxmemory_reserved
    maxfragmentationmemory_reserved = var.redis_configuration.maxfragmentationmemory_reserved
    notify_keyspace_events          = var.redis_configuration.notify_keyspace_events
    aof_backup_enabled              = var.redis_configuration.aof_backup_enabled
  }

  # Filter out null values from redis_config
  redis_config_filtered = {
    for k, v in local.redis_config : k => v if v != null
  }
}
