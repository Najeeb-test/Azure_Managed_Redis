# =============================================================================
# PRODUCTION ENVIRONMENT - MAIN CONFIGURATION
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.80.0, < 4.0.0"
    }
  }

  # Backend configuration for state management
  # REQUIRED for production - store state in Azure Storage with encryption
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state-prod"
  #   storage_account_name = "sttfstateprod"
  #   container_name       = "tfstate"
  #   key                  = "redis-cache-prod.tfstate"
  #   use_azuread_auth     = true
  # }
}

provider "azurerm" {
  features {
    # Enable additional security features for production
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

# =============================================================================
# AZURE REDIS CACHE MODULE
# =============================================================================

module "redis_cache" {
  source = "../../modules/azure-redis-cache"

  # Common variables
  resource_prefix     = var.resource_prefix
  environment         = var.environment
  location            = var.location
  resource_group_name = var.resource_group_name

  # Redis configuration
  redis_name          = var.redis_name
  sku                 = var.sku
  redis_version       = var.redis_version
  enable_non_ssl_port = var.enable_non_ssl_port
  minimum_tls_version = var.minimum_tls_version

  # Authentication
  enable_authentication      = var.enable_authentication
  aad_authentication_enabled = var.aad_authentication_enabled

  # Network configuration
  public_network_access_enabled = var.public_network_access_enabled
  subnet_id                     = var.subnet_id
  private_endpoint              = var.private_endpoint

  # High availability
  shard_count = var.shard_count
  zones       = var.zones

  # Backup configuration
  rdb_backup_enabled            = var.rdb_backup_enabled
  rdb_backup_frequency          = var.rdb_backup_frequency
  rdb_backup_max_snapshot_count = var.rdb_backup_max_snapshot_count
  rdb_storage_connection_string = var.rdb_storage_connection_string

  # Redis configuration
  redis_configuration = var.redis_configuration

  # Monitoring
  diagnostic_settings = var.diagnostic_settings

  # Tags
  tags = var.tags
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "redis_cache_id" {
  description = "The resource ID of the Redis Cache"
  value       = module.redis_cache.redis_cache_id
}

output "redis_cache_name" {
  description = "The name of the Redis Cache"
  value       = module.redis_cache.redis_cache_name
}

output "redis_cache_hostname" {
  description = "The hostname of the Redis Cache"
  value       = module.redis_cache.redis_cache_hostname
}

output "redis_cache_ssl_port" {
  description = "The SSL port of the Redis Cache"
  value       = module.redis_cache.redis_cache_ssl_port
}

output "redis_private_static_ip_address" {
  description = "The private IP address of the Redis Cache"
  value       = module.redis_cache.redis_private_static_ip_address
}

output "private_endpoint_id" {
  description = "The resource ID of the private endpoint"
  value       = module.redis_cache.private_endpoint_id
}

# Sensitive outputs - use with caution
output "redis_primary_connection_string" {
  description = "The primary connection string (SENSITIVE)"
  value       = module.redis_cache.redis_primary_connection_string
  sensitive   = true
}

output "redis_secondary_connection_string" {
  description = "The secondary connection string (SENSITIVE)"
  value       = module.redis_cache.redis_secondary_connection_string
  sensitive   = true
}
