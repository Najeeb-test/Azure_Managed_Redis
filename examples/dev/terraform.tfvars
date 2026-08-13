# =============================================================================
# DEVELOPMENT ENVIRONMENT - TERRAFORM VARIABLES
# =============================================================================
# This example demonstrates a basic Redis Cache deployment for development
# environments with relaxed security constraints.
# =============================================================================

# -----------------------------------------------------------------------------
# Common Variables
# -----------------------------------------------------------------------------

resource_prefix     = "contoso-dev-eastus-banking"
environment         = "dev"
location            = "eastus"
resource_group_name = "rg-contoso-dev-eastus"

# -----------------------------------------------------------------------------
# Redis Cache Configuration
# -----------------------------------------------------------------------------

redis_name = "cache-001"

# Standard SKU for development (cost-effective)
sku = {
  name     = "Standard"
  family   = "C"
  capacity = 1
}

# -----------------------------------------------------------------------------
# Redis Settings
# -----------------------------------------------------------------------------

redis_version       = "6"
enable_non_ssl_port = false # Keep SSL-only even in dev for security best practices
minimum_tls_version = "1.2"

# -----------------------------------------------------------------------------
# Authentication
# -----------------------------------------------------------------------------

enable_authentication      = true
aad_authentication_enabled = false # Optional: can be enabled for dev testing

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------

# Public access allowed in dev for easier testing
public_network_access_enabled = true

# VNet injection not required for dev (but can be enabled if needed)
subnet_id = null

# Private endpoint not required for dev
private_endpoint = {
  enabled              = false
  subnet_id            = null
  private_dns_zone_ids = []
}

# -----------------------------------------------------------------------------
# High Availability (Not Required for Dev)
# -----------------------------------------------------------------------------

shard_count = null
zones       = []

# -----------------------------------------------------------------------------
# Backup Configuration (Disabled for Dev)
# -----------------------------------------------------------------------------

rdb_backup_enabled            = false
rdb_backup_frequency          = 60
rdb_backup_max_snapshot_count = 1
rdb_storage_connection_string = null

# -----------------------------------------------------------------------------
# Redis Configuration
# -----------------------------------------------------------------------------

redis_configuration = {
  maxmemory_policy                = "volatile-lru"
  maxmemory_reserved              = null
  maxfragmentationmemory_reserved = null
  notify_keyspace_events          = ""
  aof_backup_enabled              = false
}

# -----------------------------------------------------------------------------
# Monitoring and Diagnostics (Optional for Dev)
# -----------------------------------------------------------------------------

diagnostic_settings = {
  enabled                        = false
  log_analytics_workspace_id     = null
  storage_account_id             = null
  eventhub_authorization_rule_id = null
  logs                           = []
  metrics                        = []
}

# Uncomment below to enable diagnostics in dev
# diagnostic_settings = {
#   enabled                    = true
#   log_analytics_workspace_id = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-monitoring-dev/providers/Microsoft.OperationalInsights/workspaces/law-dev"
#   logs = [
#     {
#       category = "ConnectedClientList"
#       enabled  = true
#       retention_policy = {
#         enabled = true
#         days    = 7
#       }
#     }
#   ]
#   metrics = [
#     {
#       category = "AllMetrics"
#       enabled  = true
#       retention_policy = {
#         enabled = true
#         days    = 7
#       }
#     }
#   ]
# }

# -----------------------------------------------------------------------------
# Mandatory Tags
# -----------------------------------------------------------------------------

tags = {
  cost_center      = "CC-12345"
  owner            = "platform-team@contoso.com"
  compliance_scope = "Internal"
  environment      = "development"
  project          = "banking-platform"
  managed_by       = "terraform"
}
