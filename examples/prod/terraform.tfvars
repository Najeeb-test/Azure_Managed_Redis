# =============================================================================
# PRODUCTION ENVIRONMENT - TERRAFORM VARIABLES
# =============================================================================
# This example demonstrates a production-grade Redis Cache deployment with
# full security, high availability, and compliance features.
# =============================================================================

# -----------------------------------------------------------------------------
# Common Variables
# -----------------------------------------------------------------------------

resource_prefix     = "contoso-prod-eastus-banking"
environment         = "prod"
location            = "eastus"
resource_group_name = "rg-contoso-prod-eastus"

# -----------------------------------------------------------------------------
# Redis Cache Configuration
# -----------------------------------------------------------------------------

redis_name = "cache-001"

# Premium SKU for production (required for HA features)
sku = {
  name     = "Premium"
  family   = "P"
  capacity = 1 # Scale as needed: P1 (6GB), P2 (13GB), P3 (26GB), P4 (53GB), P5 (120GB)
}

# -----------------------------------------------------------------------------
# Redis Settings
# -----------------------------------------------------------------------------

redis_version       = "6" # Latest stable version
enable_non_ssl_port = false # MUST be false for production
minimum_tls_version = "1.2" # MUST be 1.2 for production

# -----------------------------------------------------------------------------
# Authentication
# -----------------------------------------------------------------------------

enable_authentication      = true # MUST be true for production
aad_authentication_enabled = true # Recommended for production

# -----------------------------------------------------------------------------
# Network Configuration (PRODUCTION REQUIREMENTS)
# -----------------------------------------------------------------------------

# Public access MUST be disabled in production
public_network_access_enabled = false

# VNet injection REQUIRED for production (Premium SKU)
subnet_id = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-network-prod/providers/Microsoft.Network/virtualNetworks/vnet-prod-eastus/subnets/subnet-redis"

# Private endpoint configuration for secure access
private_endpoint = {
  enabled              = true
  subnet_id            = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-network-prod/providers/Microsoft.Network/virtualNetworks/vnet-prod-eastus/subnets/subnet-endpoints"
  private_dns_zone_ids = ["/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-dns/providers/Microsoft.Network/privateDnsZones/privatelink.redis.cache.windows.net"]
}

# -----------------------------------------------------------------------------
# High Availability Configuration
# -----------------------------------------------------------------------------

# Clustering for horizontal scaling (Premium SKU only)
shard_count = 2 # 2-10 shards supported

# Zone redundancy for 99.99% SLA (Premium SKU only)
zones = ["1", "2", "3"]

# -----------------------------------------------------------------------------
# Backup Configuration (Premium SKU)
# -----------------------------------------------------------------------------

rdb_backup_enabled            = true
rdb_backup_frequency          = 60 # Every hour (options: 15, 30, 60, 360, 720, 1440 minutes)
rdb_backup_max_snapshot_count = 7   # Keep 7 snapshots (1 week of hourly backups)

# Storage account connection string for RDB backups
# IMPORTANT: Store this in Azure Key Vault and reference securely
# Example format: "DefaultEndpointsProtocol=https;AccountName=<account>;AccountKey=<key>;EndpointSuffix=core.windows.net"
rdb_storage_connection_string = null # Set via environment variable or Key Vault reference

# -----------------------------------------------------------------------------
# Redis Configuration (Production Optimized)
# -----------------------------------------------------------------------------

redis_configuration = {
  # Memory eviction policy
  maxmemory_policy = "allkeys-lru" # Evict any key using LRU when memory limit reached

  # Reserve memory for non-cache operations (MB)
  maxmemory_reserved = 50 # Recommended: 10% of cache size

  # Reserve memory for fragmentation (MB)
  maxfragmentationmemory_reserved = 50

  # Keyspace notifications (optional)
  notify_keyspace_events = "" # Example: "Ex" for expired key events

  # AOF persistence (alternative to RDB, not commonly used)
  aof_backup_enabled = false
}

# -----------------------------------------------------------------------------
# Monitoring and Diagnostics (REQUIRED FOR PRODUCTION)
# -----------------------------------------------------------------------------

diagnostic_settings = {
  enabled = true

  # Send logs and metrics to Log Analytics
  log_analytics_workspace_id = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-prod"

  # Optional: Also send to Storage Account for long-term retention
  storage_account_id = null # "/subscriptions/.../storageAccounts/stprodlogs"

  # Optional: Stream to Event Hub for SIEM integration
  eventhub_authorization_rule_id = null

  # Log categories to capture
  logs = [
    {
      category = "ConnectedClientList"
      enabled  = true
      retention_policy = {
        enabled = true
        days    = 90 # Compliance requirement: 90-day retention
      }
    }
  ]

  # Metrics to capture
  metrics = [
    {
      category = "AllMetrics"
      enabled  = true
      retention_policy = {
        enabled = true
        days    = 90 # Compliance requirement: 90-day retention
      }
    }
  ]
}

# -----------------------------------------------------------------------------
# Mandatory Tags (PRODUCTION COMPLIANCE)
# -----------------------------------------------------------------------------

tags = {
  # Required tags
  cost_center      = "CC-67890"
  owner            = "platform-team@contoso.com"
  compliance_scope = "PCI-DSS" # Banking compliance scope

  # Additional production tags
  environment = "production"
  criticality = "high"
  backup      = "required"
  dr_tier     = "tier1"
  project     = "banking-platform"
  managed_by  = "terraform"

  # Change management
  change_ticket = "CHG0012345"
  deployed_by   = "terraform-pipeline"
  deployment_date = "2025-01-15"
}

# =============================================================================
# PRODUCTION DEPLOYMENT CHECKLIST
# =============================================================================
# Before deploying to production, ensure:
#
# ☑ Premium SKU selected
# ☑ Zone redundancy enabled (zones = ["1", "2", "3"])
# ☑ Clustering configured (shard_count >= 2)
# ☑ VNet injection configured (subnet_id set)
# ☑ Private endpoint enabled
# ☑ Public network access disabled
# ☑ TLS 1.2 enforced
# ☑ Non-SSL port disabled
# ☑ Authentication enabled
# ☑ Azure AD authentication enabled
# ☑ RDB backup enabled
# ☑ Backup storage configured
# ☑ Diagnostic settings enabled
# ☑ Log Analytics workspace configured
# ☑ 90-day log retention set
# ☑ All mandatory tags present
# ☑ Change ticket documented
# ☑ DR plan documented
# ☑ Runbook created
# ☑ Monitoring alerts configured
# ☑ Access policies documented
# ☑ Security review completed
# =============================================================================
