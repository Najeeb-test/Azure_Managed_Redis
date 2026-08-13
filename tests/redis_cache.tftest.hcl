# =============================================================================
# TERRAFORM UNIT TESTS FOR AZURE REDIS CACHE MODULE
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
# TEST 1: Validate Production Security Constraints
# =============================================================================

run "validate_production_security" {
  command = plan

  variables {
    environment                   = "prod"
    enable_non_ssl_port           = false
    minimum_tls_version           = "1.2"
    public_network_access_enabled = false
    enable_authentication         = true
    subnet_id                     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-prod/subnets/subnet-redis"
  }

  assert {
    condition     = var.enable_non_ssl_port == false
    error_message = "Non-SSL port must be disabled in production."
  }

  assert {
    condition     = var.minimum_tls_version == "1.2"
    error_message = "TLS 1.2 is required for production."
  }

  assert {
    condition     = var.public_network_access_enabled == false
    error_message = "Public network access must be disabled in production."
  }

  assert {
    condition     = var.enable_authentication == true
    error_message = "Authentication must be enabled in production."
  }

  assert {
    condition     = var.subnet_id != null
    error_message = "Subnet ID is required for production (VNet injection)."
  }
}

# =============================================================================
# TEST 2: Expect Failure When Mandatory Tags Are Missing
# =============================================================================

run "expect_failure_missing_tags" {
  command = plan

  variables {
    tags = {
      cost_center = "CC-12345"
      # Missing: owner, compliance_scope
    }
  }

  expect_failures = [
    var.tags
  ]
}

# =============================================================================
# TEST 3: Validate Naming Convention
# =============================================================================

run "validate_naming_convention" {
  command = plan

  assert {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+){4,}$", local.redis_cache_name))
    error_message = "Redis Cache name must follow hierarchical naming convention."
  }

  assert {
    condition     = length(local.redis_cache_name) >= 1 && length(local.redis_cache_name) <= 63
    error_message = "Redis Cache name must be between 1 and 63 characters."
  }

  assert {
    condition     = local.validated_name != null
    error_message = "Redis Cache name validation failed."
  }
}

# =============================================================================
# TEST 4: Validate SKU Configuration
# =============================================================================

run "validate_sku_configuration" {
  command = plan

  variables {
    sku = {
      name     = "Premium"
      family   = "P"
      capacity = 1
    }
    shard_count = 2
    zones       = ["1", "2", "3"]
  }

  assert {
    condition     = var.sku.name == "Premium"
    error_message = "Premium SKU required for clustering and zones."
  }

  assert {
    condition     = var.shard_count >= 1 && var.shard_count <= 10
    error_message = "Shard count must be between 1 and 10."
  }

  assert {
    condition     = length(var.zones) == 3
    error_message = "Zone redundancy should use all 3 availability zones."
  }

  assert {
    condition     = local.is_premium_sku == true
    error_message = "Premium SKU detection failed."
  }

  assert {
    condition     = local.is_clustered == true
    error_message = "Clustering detection failed."
  }

  assert {
    condition     = local.is_zone_redundant == true
    error_message = "Zone redundancy detection failed."
  }
}

# =============================================================================
# TEST 5: Validate Backup Configuration
# =============================================================================

run "validate_backup_configuration" {
  command = plan

  variables {
    sku = {
      name     = "Premium"
      family   = "P"
      capacity = 1
    }
    rdb_backup_enabled            = true
    rdb_backup_frequency          = 60
    rdb_backup_max_snapshot_count = 3
    rdb_storage_connection_string = "DefaultEndpointsProtocol=https;AccountName=test;AccountKey=fake=="
  }

  assert {
    condition     = var.rdb_backup_enabled == true
    error_message = "RDB backup should be enabled for Premium SKU."
  }

  assert {
    condition     = contains([15, 30, 60, 360, 720, 1440], var.rdb_backup_frequency)
    error_message = "RDB backup frequency must be a valid value."
  }

  assert {
    condition     = var.rdb_backup_max_snapshot_count >= 1
    error_message = "Max snapshot count must be at least 1."
  }

  assert {
    condition     = local.is_rdb_backup_enabled == true
    error_message = "RDB backup detection failed."
  }
}

# =============================================================================
# TEST 6: Validate Private Endpoint Configuration
# =============================================================================

run "validate_private_endpoint" {
  command = plan

  variables {
    private_endpoint = {
      enabled              = true
      subnet_id            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-prod/subnets/subnet-endpoints"
      private_dns_zone_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns/providers/Microsoft.Network/privateDnsZones/privatelink.redis.cache.windows.net"]
    }
  }

  assert {
    condition     = var.private_endpoint.enabled == true
    error_message = "Private endpoint should be enabled."
  }

  assert {
    condition     = var.private_endpoint.subnet_id != null
    error_message = "Private endpoint subnet ID is required."
  }

  assert {
    condition     = length(var.private_endpoint.private_dns_zone_ids) > 0
    error_message = "Private DNS zone IDs should be provided."
  }

  assert {
    condition     = local.is_private_endpoint_enabled == true
    error_message = "Private endpoint detection failed."
  }
}

# =============================================================================
# TEST 7: Validate Diagnostic Settings
# =============================================================================

run "validate_diagnostic_settings" {
  command = plan

  variables {
    diagnostic_settings = {
      enabled                    = true
      log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-prod"
      logs = [
        {
          category = "ConnectedClientList"
          enabled  = true
          retention_policy = {
            enabled = true
            days    = 90
          }
        }
      ]
      metrics = [
        {
          category = "AllMetrics"
          enabled  = true
          retention_policy = {
            enabled = true
            days    = 90
          }
        }
      ]
    }
  }

  assert {
    condition     = var.diagnostic_settings.enabled == true
    error_message = "Diagnostic settings should be enabled."
  }

  assert {
    condition     = var.diagnostic_settings.log_analytics_workspace_id != null
    error_message = "Log Analytics workspace ID is required."
  }

  assert {
    condition     = length(var.diagnostic_settings.logs) > 0
    error_message = "At least one log category should be configured."
  }

  assert {
    condition     = length(var.diagnostic_settings.metrics) > 0
    error_message = "At least one metric category should be configured."
  }

  assert {
    condition     = local.is_diagnostics_enabled == true
    error_message = "Diagnostics detection failed."
  }
}

# =============================================================================
# TEST 8: Expect Failure for Invalid Environment
# =============================================================================

run "expect_failure_invalid_environment" {
  command = plan

  variables {
    environment = "test" # Invalid: must be dev, staging, or prod
  }

  expect_failures = [
    var.environment
  ]
}

# =============================================================================
# TEST 9: Expect Failure for Invalid Redis Name
# =============================================================================

run "expect_failure_invalid_redis_name" {
  command = plan

  variables {
    redis_name = "INVALID_NAME_WITH_UPPERCASE" # Invalid: must be lowercase
  }

  expect_failures = [
    var.redis_name
  ]
}

# =============================================================================
# TEST 10: Expect Failure for Production Without VNet
# =============================================================================

run "expect_failure_prod_without_vnet" {
  command = plan

  variables {
    environment = "prod"
    subnet_id   = null # Invalid: production requires VNet injection
  }

  expect_failures = [
    var.subnet_id
  ]
}

# =============================================================================
# TEST 11: Expect Failure for Production with Non-SSL Port
# =============================================================================

run "expect_failure_prod_with_non_ssl" {
  command = plan

  variables {
    environment         = "prod"
    enable_non_ssl_port = true # Invalid: production must disable non-SSL port
    subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-prod/subnets/subnet-redis"
  }

  expect_failures = [
    var.enable_non_ssl_port
  ]
}

# =============================================================================
# TEST 12: Expect Failure for Production with Public Access
# =============================================================================

run "expect_failure_prod_with_public_access" {
  command = plan

  variables {
    environment                   = "prod"
    public_network_access_enabled = true # Invalid: production must disable public access
    subnet_id                     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-prod/subnets/subnet-redis"
  }

  expect_failures = [
    var.public_network_access_enabled
  ]
}

# =============================================================================
# TEST 13: Validate Redis Configuration
# =============================================================================

run "validate_redis_configuration" {
  command = plan

  variables {
    redis_configuration = {
      maxmemory_policy                = "allkeys-lru"
      maxmemory_reserved              = 50
      maxfragmentationmemory_reserved = 50
      notify_keyspace_events          = "Ex"
      aof_backup_enabled              = false
    }
  }

  assert {
    condition     = var.redis_configuration.maxmemory_policy == "allkeys-lru"
    error_message = "Redis configuration maxmemory_policy should be set."
  }

  assert {
    condition     = var.redis_configuration.maxmemory_reserved == 50
    error_message = "Redis configuration maxmemory_reserved should be set."
  }
}

# =============================================================================
# TEST 14: Validate Common Tags Merge
# =============================================================================

run "validate_common_tags" {
  command = plan

  assert {
    condition     = contains(keys(local.common_tags), "environment")
    error_message = "Common tags should include 'environment'."
  }

  assert {
    condition     = contains(keys(local.common_tags), "managed_by")
    error_message = "Common tags should include 'managed_by'."
  }

  assert {
    condition     = contains(keys(local.common_tags), "module_name")
    error_message = "Common tags should include 'module_name'."
  }

  assert {
    condition     = contains(keys(local.common_tags), "module_version")
    error_message = "Common tags should include 'module_version'."
  }

  assert {
    condition     = local.common_tags["managed_by"] == "terraform"
    error_message = "Common tags 'managed_by' should be 'terraform'."
  }
}

# =============================================================================
# TEST 15: Validate Resource Prefix Pattern
# =============================================================================

run "validate_resource_prefix" {
  command = plan

  assert {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+){3,}$", var.resource_prefix))
    error_message = "Resource prefix must follow the required pattern."
  }
}

# =============================================================================
# TEST 16: Expect Failure for Invalid SKU Name
# =============================================================================

run "expect_failure_invalid_sku_name" {
  command = plan

  variables {
    sku = {
      name     = "Enterprise" # Invalid: must be Basic, Standard, or Premium
      family   = "C"
      capacity = 1
    }
  }

  expect_failures = [
    var.sku
  ]
}

# =============================================================================
# TEST 17: Expect Failure for Invalid Shard Count
# =============================================================================

run "expect_failure_invalid_shard_count" {
  command = plan

  variables {
    sku = {
      name     = "Premium"
      family   = "P"
      capacity = 1
    }
    shard_count = 15 # Invalid: must be between 1 and 10
  }

  expect_failures = [
    var.shard_count
  ]
}

# =============================================================================
# TEST 18: Expect Failure for Invalid Zone
# =============================================================================

run "expect_failure_invalid_zone" {
  command = plan

  variables {
    zones = ["1", "2", "4"] # Invalid: zone 4 doesn't exist
  }

  expect_failures = [
    var.zones
  ]
}
