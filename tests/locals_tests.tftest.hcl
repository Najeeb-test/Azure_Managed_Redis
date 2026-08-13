# =============================================================================
# UNIT TESTS FOR LOCALS CALCULATIONS AND COMPLEX EXPRESSIONS
# Focus: Testing locals.tf logic and derived values
# =============================================================================

mock_provider "azurerm" {}

variables {
  resource_prefix     = "contoso-dev-eastus-banking"
  environment         = "dev"
  location            = "eastus"
  resource_group_name = "rg-contoso-dev-eastus"
  redis_name          = "cache-001"

  sku = {
    name     = "Standard"
    family   = "C"
    capacity = 1
  }

  tags = {
    cost_center      = "CC-12345"
    owner            = "platform-team@contoso.com"
    compliance_scope = "PCI-DSS"
  }
}

# =============================================================================
# REDIS CACHE NAME CONSTRUCTION TESTS
# =============================================================================

# TEST: Redis cache name construction
run "test_redis_cache_name_construction" {
  command = plan

  variables {
    resource_prefix = "contoso-dev-eastus-banking"
    redis_name      = "cache-001"
  }

  assert {
    condition     = local.redis_cache_name == "contoso-dev-eastus-banking-redis-cache-001"
    error_message = "Redis cache name should be constructed as: resource_prefix-redis-redis_name"
  }
}

# TEST: Redis cache name construction with different inputs
run "test_redis_cache_name_construction_alt" {
  command = plan

  variables {
    resource_prefix = "org-prod-westus-app"
    redis_name      = "primary"
  }

  assert {
    condition     = local.redis_cache_name == "org-prod-westus-app-redis-primary"
    error_message = "Redis cache name construction failed for alternative inputs."
  }
}

# =============================================================================
# VALIDATED NAME TESTS
# =============================================================================

# TEST: Validated name passes for valid input
run "test_validated_name_valid" {
  command = plan

  variables {
    resource_prefix = "contoso-dev-eastus-banking"
    redis_name      = "cache-001"
  }

  assert {
    condition     = local.validated_name != null
    error_message = "Validated name should not be null for valid inputs."
  }

  assert {
    condition     = local.validated_name == local.redis_cache_name
    error_message = "Validated name should equal redis_cache_name when valid."
  }
}

# TEST: Validated name length constraints (minimum)
run "test_validated_name_min_length" {
  command = plan

  variables {
    resource_prefix = "a-b-c-d"
    redis_name      = "x"
  }

  assert {
    condition     = length(local.redis_cache_name) >= 1
    error_message = "Redis cache name should meet minimum length requirement."
  }

  assert {
    condition     = local.validated_name != null
    error_message = "Validated name should not be null for minimum valid length."
  }
}

# TEST: Validated name length constraints (maximum boundary)
run "test_validated_name_max_length_boundary" {
  command = plan

  variables {
    resource_prefix = "contoso-prod-eastus-banking-app-service-infrastructure"
    redis_name      = "cache"
  }

  assert {
    condition     = length(local.redis_cache_name) <= 63
    error_message = "Redis cache name should not exceed 63 characters."
  }
}

# TEST: Validated name pattern validation (alphanumeric with hyphens)
run "test_validated_name_pattern" {
  command = plan

  variables {
    resource_prefix = "contoso-dev-eastus-banking"
    redis_name      = "cache-001"
  }

  assert {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", local.redis_cache_name))
    error_message = "Redis cache name should match pattern: start and end with alphanumeric, hyphens allowed in middle."
  }
}

# =============================================================================
# COMMON TAGS MERGE TESTS
# =============================================================================

# TEST: Common tags include user-provided tags
run "test_common_tags_include_user_tags" {
  command = plan

  variables {
    tags = {
      cost_center      = "CC-99999"
      owner            = "test-team@example.com"
      compliance_scope = "SOC2"
      custom_tag       = "custom_value"
    }
  }

  assert {
    condition     = local.common_tags["cost_center"] == "CC-99999"
    error_message = "Common tags should include user-provided cost_center."
  }

  assert {
    condition     = local.common_tags["owner"] == "test-team@example.com"
    error_message = "Common tags should include user-provided owner."
  }

  assert {
    condition     = local.common_tags["compliance_scope"] == "SOC2"
    error_message = "Common tags should include user-provided compliance_scope."
  }

  assert {
    condition     = local.common_tags["custom_tag"] == "custom_value"
    error_message = "Common tags should include user-provided custom tags."
  }
}

# TEST: Common tags include auto-generated tags
run "test_common_tags_include_auto_tags" {
  command = plan

  variables {
    environment = "prod"
  }

  assert {
    condition     = local.common_tags["environment"] == "prod"
    error_message = "Common tags should include environment from variable."
  }

  assert {
    condition     = local.common_tags["managed_by"] == "terraform"
    error_message = "Common tags should include managed_by = terraform."
  }

  assert {
    condition     = local.common_tags["module_name"] == "azure-redis-cache"
    error_message = "Common tags should include module_name."
  }

  assert {
    condition     = local.common_tags["module_version"] == "1.0.0"
    error_message = "Common tags should include module_version."
  }

  assert {
    condition     = local.common_tags["terraform_module"] == "true"
    error_message = "Common tags should include terraform_module = true."
  }
}

# TEST: Common tags merge doesn't lose user tags
run "test_common_tags_merge_preserves_all" {
  command = plan

  variables {
    tags = {
      cost_center      = "CC-12345"
      owner            = "platform-team@contoso.com"
      compliance_scope = "PCI-DSS"
      project          = "redis-migration"
      team             = "platform"
    }
  }

  assert {
    condition     = length(keys(local.common_tags)) >= 8
    error_message = "Common tags should contain at least 8 keys (3 mandatory + 2 custom + 5 auto-generated)."
  }

  assert {
    condition     = contains(keys(local.common_tags), "project")
    error_message = "Common tags should preserve custom 'project' tag."
  }

  assert {
    condition     = contains(keys(local.common_tags), "team")
    error_message = "Common tags should preserve custom 'team' tag."
  }
}

# =============================================================================
# PREMIUM SKU DETECTION TESTS
# =============================================================================

# TEST: Premium SKU detection (true)
run "test_is_premium_sku_true" {
  command = plan

  variables {
    sku = {
      name     = "Premium"
      family   = "P"
      capacity = 1
    }
  }

  assert {
    condition     = local.is_premium_sku == true
    error_message = "is_premium_sku should be true when SKU name is Premium."
  }
}

# TEST: Premium SKU detection (false for Standard)
run "test_is_premium_sku_false_standard" {
  command = plan

  variables {
    sku = {
      name     = "Standard"
      family   = "C"
      capacity = 1
    }
  }

  assert {
    condition     = local.is_premium_sku == false
    error_message = "is_premium_sku should be false when SKU name is Standard."
  }
}

# TEST: Premium SKU detection (false for Basic)
run "test_is_premium_sku_false_basic" {
  command = plan

  variables {
    sku = {
      name     = "Basic"
      family   = "C"
      capacity = 0
    }
  }

  assert {
    condition     = local.is_premium_sku == false
    error_message = "is_premium_sku should be false when SKU name is Basic."
  }
}

# =============================================================================
# CLUSTERING DETECTION TESTS
# =============================================================================

# TEST: Clustering enabled (Premium + shard_count > 0)
run "test_is_clustered_true" {
  command = plan

  variables {
    sku = {
      name     = "Premium"
      family   = "P"
      capacity = 1
    }
    shard_count = 3
  }

  assert {
    condition     = local.is_clustered == true
    error_message = "is_clustered should be true when Premium SKU and shard_count > 0."
  }
}

# TEST: Clustering disabled (Premium but shard_count = null)
run "test_is_clustered_false_null_shards" {
  command = plan

  variables {
    sku = {
      name     = "Premium"
      family   = "P"
      capacity = 1
    }
    shard_count = null
  }

  assert {
    condition     = local.is_clustered == false
    error_message = "is_clustered should be false when shard_count is null."
  }
}

# TEST: Clustering disabled (Premium but shard_count = 0)
run "test_is_clustered_false_zero_shards" {
  command = plan

  variables {
    sku = {
      name     = "Premium"
      family   = "P"
      capacity = 1
    }
    shard_count = 0
  }

  assert {
    condition     = local.is_clustered == false
    error_message = "is_clustered should be false when shard_count is 0."
  }
}

# TEST: Clustering disabled (Standard SKU, even with shard_count)
run "test_is_clustered_false_non_premium" {
  command = plan

  variables {
    sku = {
      name     = "Standard"
      family   = "C"
      capacity = 1
    }
    shard_count = 3
  }

  assert {
    condition     = local.is_clustered == false
    error_message = "is_clustered should be false for non-Premium SKU."
  }
}

# =============================================================================
# ZONE REDUNDANCY DETECTION TESTS
# =============================================================================

# TEST: Zone redundancy enabled (Premium + zones provided)
run "test_is_zone_redundant_true" {
  command = plan

  variables {
    sku = {
      name     = "Premium"
      family   = "P"
      capacity = 1
    }
    zones = ["1", "2", "3"]
  }

  assert {
    condition     = local.is_zone_redundant == true
    error_message = "is_zone_redundant should be true when Premium SKU and zones are provided."
  }
}

# TEST: Zone redundancy disabled (Premium but empty zones)
run "test_is_zone_redundant_false_empty_zones" {
  command = plan

  variables {
    sku = {
      name     = "Premium"
      family   = "P"
      capacity = 1
    }
    zones = []
  }

  assert {
    condition     = local.is_zone_redundant == false
    error_message = "is_zone_redundant should be false when zones list is empty."
  }
}

# TEST: Zone redundancy disabled (Standard SKU, even with zones)
run "test_is_zone_redundant_false_non_premium" {
  command = plan

  variables {
    sku = {
      name     = "Standard"
      family   = "C"
      capacity = 1
    }
    zones = ["1", "2"]
  }

  assert {
    condition     = local.is_zone_redundant == false
    error_message = "is_zone_redundant should be false for non-Premium SKU."
  }
}

# =============================================================================
# VNET INJECTION DETECTION TESTS
# =============================================================================

# TEST: VNet injection enabled (subnet_id provided)
run "test_is_vnet_injected_true" {
  command = plan

  variables {
    subnet_id = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-prod/subnets/subnet-redis"
  }

  assert {
    condition     = local.is_vnet_injected == true
    error_message = "is_vnet_injected should be true when subnet_id is provided."
  }
}

# TEST: VNet injection disabled (subnet_id = null)
run "test_is_vnet_injected_false" {
  command = plan

  variables {
    subnet_id = null
  }

  assert {
    condition     = local.is_vnet_injected == false
    error_message = "is_vnet_injected should be false when subnet_id is null."
  }
}

# =============================================================================
# PRIVATE ENDPOINT DETECTION TESTS
# =============================================================================

# TEST: Private endpoint enabled
run "test_is_private_endpoint_enabled_true" {
  command = plan

  variables {
    private_endpoint = {
      enabled              = true
      subnet_id            = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-prod/subnets/subnet-endpoints"
      private_dns_zone_ids = ["/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-dns/providers/Microsoft.Network/privateDnsZones/privatelink.redis.cache.windows.net"]
    }
  }

  assert {
    condition     = local.is_private_endpoint_enabled == true
    error_message = "is_private_endpoint_enabled should be true when private_endpoint.enabled is true."
  }
}

# TEST: Private endpoint disabled
run "test_is_private_endpoint_enabled_false" {
  command = plan

  variables {
    private_endpoint = {
      enabled              = false
      subnet_id            = null
      private_dns_zone_ids = []
    }
  }

  assert {
    condition     = local.is_private_endpoint_enabled == false
    error_message = "is_private_endpoint_enabled should be false when private_endpoint.enabled is false."
  }
}

# =============================================================================
# DIAGNOSTICS DETECTION TESTS
# =============================================================================

# TEST: Diagnostics enabled
run "test_is_diagnostics_enabled_true" {
  command = plan

  variables {
    diagnostic_settings = {
      enabled                    = true
      log_analytics_workspace_id = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-prod"
    }
  }

  assert {
    condition     = local.is_diagnostics_enabled == true
    error_message = "is_diagnostics_enabled should be true when diagnostic_settings.enabled is true."
  }
}

# TEST: Diagnostics disabled
run "test_is_diagnostics_enabled_false" {
  command = plan

  variables {
    diagnostic_settings = {
      enabled = false
    }
  }

  assert {
    condition     = local.is_diagnostics_enabled == false
    error_message = "is_diagnostics_enabled should be false when diagnostic_settings.enabled is false."
  }
}

# =============================================================================
# RDB BACKUP DETECTION TESTS
# =============================================================================

# TEST: RDB backup enabled (Premium + rdb_backup_enabled = true)
run "test_is_rdb_backup_enabled_true" {
  command = plan

  variables {
    sku = {
      name     = "Premium"
      family   = "P"
      capacity = 1
    }
    rdb_backup_enabled = true
  }

  assert {
    condition     = local.is_rdb_backup_enabled == true
    error_message = "is_rdb_backup_enabled should be true when Premium SKU and rdb_backup_enabled is true."
  }
}

# TEST: RDB backup disabled (Premium but rdb_backup_enabled = false)
run "test_is_rdb_backup_enabled_false_disabled" {
  command = plan

  variables {
    sku = {
      name     = "Premium"
      family   = "P"
      capacity = 1
    }
    rdb_backup_enabled = false
  }

  assert {
    condition     = local.is_rdb_backup_enabled == false
    error_message = "is_rdb_backup_enabled should be false when rdb_backup_enabled is false."
  }
}

# TEST: RDB backup disabled (Standard SKU, even with rdb_backup_enabled = true)
run "test_is_rdb_backup_enabled_false_non_premium" {
  command = plan

  variables {
    sku = {
      name     = "Standard"
      family   = "C"
      capacity = 1
    }
    rdb_backup_enabled = true
  }

  assert {
    condition     = local.is_rdb_backup_enabled == false
    error_message = "is_rdb_backup_enabled should be false for non-Premium SKU."
  }
}

# =============================================================================
# REDIS CONFIG FILTERED TESTS
# =============================================================================

# TEST: Redis config filtered removes null values
run "test_redis_config_filtered_removes_nulls" {
  command = plan

  variables {
    redis_configuration = {
      maxmemory_policy                = "volatile-lru"
      maxmemory_reserved              = null
      maxfragmentationmemory_reserved = null
      notify_keyspace_events          = ""
      aof_backup_enabled              = false
    }
  }

  assert {
    condition     = !contains(keys(local.redis_config_filtered), "maxmemory_reserved") || local.redis_config_filtered["maxmemory_reserved"] != null
    error_message = "redis_config_filtered should not contain null maxmemory_reserved."
  }

  assert {
    condition     = !contains(keys(local.redis_config_filtered), "maxfragmentationmemory_reserved") || local.redis_config_filtered["maxfragmentationmemory_reserved"] != null
    error_message = "redis_config_filtered should not contain null maxfragmentationmemory_reserved."
  }
}

# TEST: Redis config filtered preserves non-null values
run "test_redis_config_filtered_preserves_values" {
  command = plan

  variables {
    redis_configuration = {
      maxmemory_policy                = "allkeys-lru"
      maxmemory_reserved              = 50
      maxfragmentationmemory_reserved = 50
      notify_keyspace_events          = "Ex"
      aof_backup_enabled              = true
    }
  }

  assert {
    condition     = local.redis_config_filtered["maxmemory_policy"] == "allkeys-lru"
    error_message = "redis_config_filtered should preserve maxmemory_policy."
  }

  assert {
    condition     = local.redis_config_filtered["maxmemory_reserved"] == 50
    error_message = "redis_config_filtered should preserve maxmemory_reserved."
  }

  assert {
    condition     = local.redis_config_filtered["maxfragmentationmemory_reserved"] == 50
    error_message = "redis_config_filtered should preserve maxfragmentationmemory_reserved."
  }

  assert {
    condition     = local.redis_config_filtered["notify_keyspace_events"] == "Ex"
    error_message = "redis_config_filtered should preserve notify_keyspace_events."
  }

  assert {
    condition     = local.redis_config_filtered["aof_backup_enabled"] == true
    error_message = "redis_config_filtered should preserve aof_backup_enabled."
  }
}
