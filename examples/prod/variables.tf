# =============================================================================
# PRODUCTION ENVIRONMENT - VARIABLE DECLARATIONS
# =============================================================================
# This file declares all variables used in the prod example.
# Values are provided in terraform.tfvars
# =============================================================================

variable "resource_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "redis_name" {
  description = "Redis Cache name"
  type        = string
}

variable "sku" {
  description = "Redis Cache SKU"
  type = object({
    name     = string
    family   = string
    capacity = number
  })
}

variable "redis_version" {
  description = "Redis version"
  type        = string
  default     = "6"
}

variable "enable_non_ssl_port" {
  description = "Enable non-SSL port"
  type        = bool
  default     = false
}

variable "minimum_tls_version" {
  description = "Minimum TLS version"
  type        = string
  default     = "1.2"
}

variable "enable_authentication" {
  description = "Enable authentication"
  type        = bool
  default     = true
}

variable "aad_authentication_enabled" {
  description = "Enable Azure AD authentication"
  type        = bool
  default     = false
}

variable "public_network_access_enabled" {
  description = "Enable public network access"
  type        = bool
  default     = false
}

variable "subnet_id" {
  description = "Subnet ID for VNet injection"
  type        = string
  default     = null
}

variable "private_endpoint" {
  description = "Private endpoint configuration"
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

variable "shard_count" {
  description = "Number of shards"
  type        = number
  default     = null
}

variable "zones" {
  description = "Availability zones"
  type        = list(string)
  default     = []
}

variable "rdb_backup_enabled" {
  description = "Enable RDB backup"
  type        = bool
  default     = false
}

variable "rdb_backup_frequency" {
  description = "RDB backup frequency"
  type        = number
  default     = 60
}

variable "rdb_backup_max_snapshot_count" {
  description = "Max RDB snapshots"
  type        = number
  default     = 1
}

variable "rdb_storage_connection_string" {
  description = "Storage connection string for backups"
  type        = string
  default     = null
  sensitive   = true
}

variable "redis_configuration" {
  description = "Redis configuration"
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

variable "diagnostic_settings" {
  description = "Diagnostic settings"
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

variable "tags" {
  description = "Resource tags"
  type        = map(string)
}
