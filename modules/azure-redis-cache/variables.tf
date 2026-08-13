# =============================================================================
# COMMON/SHARED VARIABLES (DRY Principle)
# =============================================================================

# -----------------------------------------------------------------------------
# Naming and Identification
# -----------------------------------------------------------------------------

variable "resource_prefix" {
  description = "Prefix for all resource names following bank's hierarchical naming convention. Format: <org>-<env>-<region>-<app>"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+){3,}$", var.resource_prefix))
    error_message = "Resource prefix must follow lowercase_with_underscores/hyphens pattern with at least 4 segments."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod). Used for tagging and naming."
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "Azure region for Redis Cache deployment."
  type        = string
  validation {
    condition     = can(regex("^[a-z]+$", var.location))
    error_message = "Location must be a valid Azure region in lowercase (e.g., eastus, westeurope)."
  }
}

variable "resource_group_name" {
  description = "Name of the existing Azure Resource Group where Redis Cache will be deployed."
  type        = string
  validation {
    condition     = length(var.resource_group_name) > 0 && length(var.resource_group_name) <= 90
    error_message = "Resource group name must be between 1 and 90 characters."
  }
}

# -----------------------------------------------------------------------------
# Tagging (DRY - reusable across modules)
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Common tags to apply to all resources. Must include mandatory bank tags: cost_center, owner, compliance_scope."
  type        = map(string)
  default     = {}
  validation {
    condition = alltrue([
      contains(keys(var.tags), "cost_center"),
      contains(keys(var.tags), "owner"),
      contains(keys(var.tags), "compliance_scope")
    ])
    error_message = "Tags must include mandatory keys: cost_center, owner, compliance_scope."
  }
}

# =============================================================================
# REDIS-SPECIFIC CONFIGURATION
# =============================================================================

# -----------------------------------------------------------------------------
# Core Redis Settings
# -----------------------------------------------------------------------------

variable "redis_name" {
  description = "Name of the Redis Cache instance. Will be combined with resource_prefix. Must be globally unique."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]{1,63}$", var.redis_name))
    error_message = "Redis name must be lowercase alphanumeric with hyphens, max 63 characters."
  }
}

variable "sku" {
  description = "Redis Cache SKU configuration."
  type = object({
    name     = string # Basic, Standard, Premium
    family   = string # C (Basic/Standard), P (Premium)
    capacity = number # 0-6 for C family, 1-5 for P family
  })
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku.name)
    error_message = "SKU name must be one of: Basic, Standard, Premium."
  }
  validation {
    condition     = contains(["C", "P"], var.sku.family)
    error_message = "SKU family must be C (Basic/Standard) or P (Premium)."
  }
  validation {
    condition     = var.sku.capacity >= 0 && var.sku.capacity <= 6
    error_message = "SKU capacity must be between 0 and 6."
  }
}

variable "redis_version" {
  description = "Redis version to deploy. Banking standard: use latest stable (6)."
  type        = string
  default     = "6"
  validation {
    condition     = contains(["4", "6"], var.redis_version)
    error_message = "Redis version must be 4 or 6."
  }
}

variable "enable_non_ssl_port" {
  description = "Enable non-SSL port (6379). MUST be false for banking/production environments."
  type        = bool
  default     = false
  validation {
    condition     = var.environment == "prod" ? var.enable_non_ssl_port == false : true
    error_message = "Non-SSL port must be disabled in production environments."
  }
}

variable "minimum_tls_version" {
  description = "Minimum TLS version for connections. Banking standard: 1.2 minimum."
  type        = string
  default     = "1.2"
  validation {
    condition     = contains(["1.0", "1.1", "1.2"], var.minimum_tls_version)
    error_message = "Minimum TLS version must be 1.0, 1.1, or 1.2."
  }
  validation {
    condition     = var.environment == "prod" ? var.minimum_tls_version == "1.2" : true
    error_message = "Production environments must use TLS 1.2."
  }
}

# -----------------------------------------------------------------------------
# High Availability and Clustering
# -----------------------------------------------------------------------------

variable "shard_count" {
  description = "Number of shards for Premium SKU clustering. Only applicable for Premium tier."
  type        = number
  default     = null
  validation {
    condition     = var.shard_count == null || (var.shard_count >= 1 && var.shard_count <= 10)
    error_message = "Shard count must be between 1 and 10 when specified."
  }
}

variable "zones" {
  description = "Availability zones for zone-redundant deployment. Requires Premium SKU."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for z in var.zones : contains(["1", "2", "3"], z)])
    error_message = "Zones must be a list containing values from: 1, 2, 3."
  }
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------

variable "subnet_id" {
  description = "Subnet ID for private Redis deployment (Premium SKU only). Required for production."
  type        = string
  default     = null
  validation {
    condition     = var.subnet_id == null || can(regex("^/subscriptions/.+/resourceGroups/.+/providers/Microsoft.Network/virtualNetworks/.+/subnets/.+$", var.subnet_id))
    error_message = "Subnet ID must be a valid Azure subnet resource ID."
  }
  validation {
    condition     = var.environment == "prod" ? var.subnet_id != null : true
    error_message = "Subnet ID is required for production environments (VNet injection)."
  }
}

variable "private_endpoint" {
  description = "Private endpoint configuration for secure access."
  type = object({
    enabled              = bool
    subnet_id            = string
    private_dns_zone_ids = list(string)
  })
  default = {
    enabled              = false
    subnet_id            = null
    private_dns_zone_ids = []
  }
}

variable "public_network_access_enabled" {
  description = "Enable public network access. MUST be false for production."
  type        = bool
  default     = false
  validation {
    condition     = var.environment == "prod" ? var.public_network_access_enabled == false : true
    error_message = "Public network access must be disabled in production."
  }
}

# -----------------------------------------------------------------------------
# Backup and Persistence (Premium SKU)
# -----------------------------------------------------------------------------

variable "rdb_backup_enabled" {
  description = "Enable RDB persistence backup. Recommended for production."
  type        = bool
  default     = false
}

variable "rdb_backup_frequency" {
  description = "Backup frequency in minutes. Valid values: 15, 30, 60, 360, 720, 1440."
  type        = number
  default     = 60
  validation {
    condition     = var.rdb_backup_enabled ? contains([15, 30, 60, 360, 720, 1440], var.rdb_backup_frequency) : true
    error_message = "RDB backup frequency must be one of: 15, 30, 60, 360, 720, 1440 minutes."
  }
}

variable "rdb_backup_max_snapshot_count" {
  description = "Maximum number of snapshots to retain."
  type        = number
  default     = 1
  validation {
    condition     = var.rdb_backup_max_snapshot_count >= 1
    error_message = "Max snapshot count must be at least 1."
  }
}

variable "rdb_storage_connection_string" {
  description = "Azure Storage connection string for RDB backups. SENSITIVE."
  type        = string
  default     = null
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Authentication and Security
# -----------------------------------------------------------------------------

variable "redis_configuration" {
  description = "Advanced Redis configuration settings."
  type = object({
    maxmemory_policy                = optional(string, "volatile-lru")
    maxmemory_reserved              = optional(number, null)
    maxfragmentationmemory_reserved = optional(number, null)
    notify_keyspace_events          = optional(string, "")
    aof_backup_enabled              = optional(bool, false)
  })
  default = {
    maxmemory_policy = "volatile-lru"
  }
}

variable "enable_authentication" {
  description = "Require authentication (access key). MUST be true for production."
  type        = bool
  default     = true
  validation {
    condition     = var.environment == "prod" ? var.enable_authentication == true : true
    error_message = "Authentication must be enabled in production."
  }
}

variable "aad_authentication_enabled" {
  description = "Enable Azure Active Directory (Entra ID) authentication. Recommended for production."
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Monitoring and Diagnostics
# -----------------------------------------------------------------------------

variable "diagnostic_settings" {
  description = "Diagnostic settings for Redis Cache monitoring."
  type = object({
    enabled                        = bool
    log_analytics_workspace_id     = optional(string, null)
    storage_account_id             = optional(string, null)
    eventhub_authorization_rule_id = optional(string, null)
    logs = optional(list(object({
      category = string
      enabled  = bool
      retention_policy = object({
        enabled = bool
        days    = number
      })
    })), [])
    metrics = optional(list(object({
      category = string
      enabled  = bool
      retention_policy = object({
        enabled = bool
        days    = number
      })
    })), [])
  })
  default = {
    enabled = false
  }
}
