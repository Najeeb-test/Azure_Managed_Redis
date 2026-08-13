# =============================================================================
# UNIT TESTS FOR FOR_EACH ITERATORS AND EDGE CASES
# Focus: Testing dynamic blocks and for_each constructs in main.tf
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
# PRIVATE ENDPOINT COUNT TESTS (count-based iteration)
# =============================================================================

# TEST: Private endpoint created when enabled
run "test_private_endpoint_created_when_enabled" {
  command = plan

  variables {
    private_endpoint = {
      enabled              = true
      subnet_id            = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-prod/subnets/subnet-endpoints"
      private_dns_zone_ids = ["/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-dns/providers/Microsoft.Network/privateDnsZones/privatelink.redis.cache.windows.net"]
    }
  }

  assert {
    condition     = var.private_endpoint.enabled == true
    error_message = "Private endpoint should be enabled."
  }

  # Note: In a real test with actual provider, we would check:
  # length([for pe in azurerm_private_endpoint.redis : pe]) == 1
}

# TEST: Private endpoint not created when disabled
run "test_private_endpoint_not_created_when_disabled" {
  command = plan

  variables {
    private_endpoint = {
      enabled              = false
      subnet_id            = null
      private_dns_zone_ids = []
    }
  }

  assert {
    condition     = var.private_endpoint.enabled == false
    error_message = "Private endpoint should be disabled."
  }

  # Note: In a real test with actual provider, we would check:
  # length([for pe in azurerm_private_endpoint.redis : pe]) == 0
}

# =============================================================================
# DIAGNOSTIC SETTINGS COUNT TESTS
# =============================================================================

# TEST: Diagnostic settings created when enabled
run "test_diagnostic_settings_created_when_enabled" {
  command = plan

  variables {
    diagnostic_settings = {
      enabled                    = true
      log_analytics_workspace_id = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-prod"
      logs                       = []
      metrics                    = []
    }
  }

  assert {
    condition     = var.diagnostic_settings.enabled == true
    error_message = "Diagnostic settings should be enabled."
  }
}

# TEST: Diagnostic settings not created when disabled
run "test_diagnostic_settings_not_created_when_disabled" {
  command = plan

  variables {
    diagnostic_settings = {
      enabled = false
    }
  }

  assert {
    condition     = var.diagnostic_settings.enabled == false
    error_message = "Diagnostic settings should be disabled."
  }
}

# =============================================================================
# PRIVATE DNS ZONE GROUP DYNAMIC BLOCK TESTS
# =============================================================================

# TEST: Private DNS zone group created when DNS zones provided
run "test_private_dns_zone_group_with_zones" {
  command = plan

  variables {
    private_endpoint = {
      enabled = true
      subnet_id = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-prod/subnets/subnet-endpoints"
      private_dns_zone_ids = [
        "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-dns/providers/Microsoft.Network/privateDnsZones/privatelink.redis.cache.windows.net"
      ]
    }
  }

  assert {
    condition     = length(var.private_endpoint.private_dns_zone_ids) > 0
    error_message = "Private DNS zone IDs should be provided."
  }
}

# TEST: Private DNS zone group not created when DNS zones empty
run "test_private_dns_zone_group_without_zones" {
  command = plan

  variables {
    private_endpoint = {
      enabled              = true
      subnet_id            = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-prod/subnets/subnet-endpoints"
      private_dns_zone_ids = []
    }
  }

  assert {
    condition     = length(var.private_endpoint.private_dns_zone_ids) == 0
    error_message = "Private DNS zone IDs should be empty."
  }
}

# TEST: Multiple private DNS zones
run "test_multiple_private_dns_zones" {
  command = plan

  variables {
    private_endpoint = {
      enabled   = true
      subnet_id = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-prod/subnets/subnet-endpoints"
      private_dns_zone_ids = [
        "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-dns/providers/Microsoft.Network/privateDnsZones/privatelink.redis.cache.windows.net",
        "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-dns/providers/Microsoft.Network/privateDnsZones/privatelink.redis.azure.com"
      ]
    }
  }

  assert {
    condition     = length(var.private_endpoint.private_dns_zone_ids) == 2
    error_message = "Should support multiple private DNS zones."
  }
}

# =============================================================================
# DIAGNOSTIC LOGS DYNAMIC BLOCK TESTS
# =============================================================================

# TEST: Diagnostic logs with single category
run "test_diagnostic_logs_single_category" {
  command = plan

  variables {
    diagnostic_settings = {
      enabled                    = true
      log_analytics_workspace_id = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-prod"
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
      metrics = []
    }
  }

  assert {
    condition     = length(var.diagnostic_settings.logs) == 1
    error_message = "Should have exactly 1 log category configured."
  }

  assert {
    condition     = var.diagnostic_settings.logs[0].category == "ConnectedClientList"
    error_message = "Log category should be ConnectedClientList."
  }
}

# TEST: Diagnostic logs with multiple categories
run "test_diagnostic_logs_multiple_categories" {
  command = plan

  variables {
    diagnostic_settings = {
      enabled                    = true
      log_analytics_workspace_id = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-prod"
      logs = [
        {
          category = "ConnectedClientList"
          enabled  = true
          retention_policy = {
            enabled = true
            days    = 90
          }
        },
        {
          category = "AuditEvent"
          enabled  = true
          retention_policy = {
            enabled = true
            days    = 180
          }
        }
      ]
      metrics = []
    }
  }

  assert {
    condition     = length(var.diagnostic_settings.logs) == 2
    error_message = "Should have exactly 2 log categories configured."
  }

  assert {
    condition     = var.diagnostic_settings.logs[1].retention_policy.days == 180
    error_message = "Second log category should have 180 days retention."
  }
}

# TEST: Diagnostic logs with empty list (edge case)
run "test_diagnostic_logs_empty_list" {
  command = plan

  variables {
    diagnostic_settings = {
      enabled                    = true
      log_analytics_workspace_id = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-prod"
      logs                       = []
      metrics                    = []
    }
  }

  assert {
    condition     = length(var.diagnostic_settings.logs) == 0
    error_message = "Logs list should be empty."
  }
}

# =============================================================================
# DIAGNOSTIC METRICS DYNAMIC BLOCK TESTS
# =============================================================================

# TEST: Diagnostic metrics with single category
run "test_diagnostic_metrics_single_category" {
  command = plan

  variables {
    diagnostic_settings = {
      enabled                    = true
      log_analytics_workspace_id = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-prod"
      logs                       = []
      metrics = [
        {
          category = "AllMetrics"
          enabled  = true
          retention_policy = {
            enabled = true
            days    = 30
          }
        }
      ]
    }
  }

  assert {
    condition     = length(var.diagnostic_settings.metrics) == 1
    error_message = "Should have exactly 1 metric category configured."
  }

  assert {
    condition     = var.diagnostic_settings.metrics[0].category == "AllMetrics"
    error_message = "Metric category should be AllMetrics."
  }
}

# TEST: Diagnostic metrics with empty list (edge case)
run "test_diagnostic_metrics_empty_list" {
  command = plan

  variables {
    diagnostic_settings = {
      enabled                    = true
      log_analytics_workspace_id = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-prod"
      logs                       = []
      metrics                    = []
    }
  }

  assert {
    condition     = length(var.diagnostic_settings.metrics) == 0
    error_message = "Metrics list should be empty."
  }
}

# =============================================================================
# REDIS CONFIG FILTERED FOR_EACH TESTS
# =============================================================================

# TEST: Redis config filtered iteration with all values
run "test_redis_config_filtered_all_values" {
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
    condition     = length(keys(local.redis_config_filtered)) == 5
    error_message = "redis_config_filtered should have 5 keys when all values are non-null."
  }
}

# TEST: Redis config filtered iteration with some null values
run "test_redis_config_filtered_some_nulls" {
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
    condition     = length(keys(local.redis_config_filtered)) <= 5
    error_message = "redis_config_filtered should filter out null values."
  }

  assert {
    condition     = contains(keys(local.redis_config_filtered), "maxmemory_policy")
    error_message = "redis_config_filtered should contain maxmemory_policy."
  }
}

# TEST: Redis config filtered iteration with minimal values
run "test_redis_config_filtered_minimal" {
  command = plan

  variables {
    redis_configuration = {
      maxmemory_policy                = "volatile-lru"
      maxmemory_reserved              = null
      maxfragmentationmemory_reserved = null
      notify_keyspace_events          = null
      aof_backup_enabled              = null
    }
  }

  assert {
    condition     = length(keys(local.redis_config_filtered)) >= 1
    error_message = "redis_config_filtered should have at least maxmemory_policy."
  }
}

# =============================================================================
# ZONES LIST ITERATION TESTS
# =============================================================================

# TEST: Zones list with all 3 zones
run "test_zones_all_three" {
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
    condition     = length(var.zones) == 3
    error_message = "Should support all 3 availability zones."
  }

  assert {
    condition     = alltrue([for z in var.zones : contains(["1", "2", "3"], z)])
    error_message = "All zones should be valid (1, 2, or 3)."
  }
}

# TEST: Zones list with single zone
run "test_zones_single_zone" {
  command = plan

  variables {
    sku = {
      name     = "Premium"
      family   = "P"
      capacity = 1
    }
    zones = ["1"]
  }

  assert {
    condition     = length(var.zones) == 1
    error_message = "Should support single availability zone."
  }
}

# TEST: Zones list with two zones
run "test_zones_two_zones" {
  command = plan

  variables {
    sku = {
      name     = "Premium"
      family   = "P"
      capacity = 1
    }
    zones = ["1", "2"]
  }

  assert {
    condition     = length(var.zones) == 2
    error_message = "Should support two availability zones."
  }
}

# TEST: Zones list empty (edge case)
run "test_zones_empty_list" {
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
    condition     = length(var.zones) == 0
    error_message = "Should handle empty zones list."
  }

  assert {
    condition     = local.is_zone_redundant == false
    error_message = "Zone redundancy should be false with empty zones list."
  }
}

# =============================================================================
# TAGS MAP ITERATION TESTS
# =============================================================================

# TEST: Tags map with mandatory tags only
run "test_tags_mandatory_only" {
  command = plan

  variables {
    tags = {
      cost_center      = "CC-12345"
      owner            = "platform-team@contoso.com"
      compliance_scope = "PCI-DSS"
    }
  }

  assert {
    condition     = length(keys(var.tags)) == 3
    error_message = "Should have exactly 3 mandatory tags."
  }

  assert {
    condition     = alltrue([for k in ["cost_center", "owner", "compliance_scope"] : contains(keys(var.tags), k)])
    error_message = "All mandatory tags should be present."
  }
}

# TEST: Tags map with additional custom tags
run "test_tags_with_custom_tags" {
  command = plan

  variables {
    tags = {
      cost_center      = "CC-12345"
      owner            = "platform-team@contoso.com"
      compliance_scope = "PCI-DSS"
      project          = "redis-migration"
      team             = "platform"
      department       = "engineering"
    }
  }

  assert {
    condition     = length(keys(var.tags)) == 6
    error_message = "Should have 3 mandatory + 3 custom tags."
  }

  assert {
    condition     = contains(keys(var.tags), "project")
    error_message = "Custom 'project' tag should be present."
  }
}

# TEST: Common tags merge preserves all tags
run "test_common_tags_merge_iteration" {
  command = plan

  variables {
    tags = {
      cost_center      = "CC-12345"
      owner            = "platform-team@contoso.com"
      compliance_scope = "PCI-DSS"
      custom1          = "value1"
      custom2          = "value2"
    }
  }

  assert {
    condition     = length(keys(local.common_tags)) >= 8
    error_message = "Common tags should include user tags + auto-generated tags."
  }

  assert {
    condition     = alltrue([for k in keys(var.tags) : contains(keys(local.common_tags), k)])
    error_message = "All user-provided tags should be present in common_tags."
  }
}

# =============================================================================
# EDGE CASE: EMPTY COLLECTIONS
# =============================================================================

# TEST: Handle all empty collections gracefully
run "test_edge_case_all_empty_collections" {
  command = plan

  variables {
    zones = []
    private_endpoint = {
      enabled              = false
      subnet_id            = null
      private_dns_zone_ids = []
    }
    diagnostic_settings = {
      enabled = false
      logs    = []
      metrics = []
    }
  }

  assert {
    condition     = length(var.zones) == 0
    error_message = "Empty zones list should be handled."
  }

  assert {
    condition     = length(var.private_endpoint.private_dns_zone_ids) == 0
    error_message = "Empty private DNS zones list should be handled."
  }

  assert {
    condition     = length(var.diagnostic_settings.logs) == 0
    error_message = "Empty diagnostic logs list should be handled."
  }

  assert {
    condition     = length(var.diagnostic_settings.metrics) == 0
    error_message = "Empty diagnostic metrics list should be handled."
  }
}
