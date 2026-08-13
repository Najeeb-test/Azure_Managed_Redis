# Azure Redis Cache Terraform Module

## Overview

This Terraform module provisions an Azure Cache for Redis instance with enterprise-grade security, high availability, and compliance features suitable for banking and financial services environments.

## Module Version

**Version:** 1.0.0  
**Status:** Production Ready  
**Last Updated:** 2025-01-15

## Features

- ✅ **Security First**: TLS 1.2 enforcement, authentication required, private networking support
- ✅ **High Availability**: Zone redundancy, clustering, and Premium SKU support
- ✅ **Compliance Ready**: Mandatory tagging, audit logging, encryption at rest and in transit
- ✅ **Network Isolation**: VNet injection and Private Endpoint support
- ✅ **Backup & Recovery**: RDB persistence with configurable backup schedules
- ✅ **Monitoring**: Integrated diagnostic settings for Azure Monitor
- ✅ **Hierarchical Naming**: Enforced organizational naming conventions
- ✅ **Environment Validation**: Production-specific security constraints

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure Resource Group                     │
│                                                             │
│  ┌────────────────────────────────────────────────────┐   │
│  │         Azure Cache for Redis (Premium)            │   │
│  │  • Zone Redundant (Zones 1, 2, 3)                  │   │
│  │  • Clustering Enabled (2+ Shards)                  │   │
│  │  • VNet Injected                                   │   │
│  │  • TLS 1.2 Enforced                                │   │
│  │  • RDB Backup Enabled                              │   │
│  └────────────────────────────────────────────────────┘   │
│                          │                                  │
│                          │ Private Endpoint                 │
│                          ▼                                  │
│  ┌────────────────────────────────────────────────────┐   │
│  │         Private Endpoint                           │   │
│  │  • Private DNS Integration                         │   │
│  │  • No Public Access                                │   │
│  └────────────────────────────────────────────────────┘   │
│                          │                                  │
│                          ▼                                  │
│  ┌────────────────────────────────────────────────────┐   │
│  │         Diagnostic Settings                        │   │
│  │  • Log Analytics Workspace                         │   │
│  │  • Metrics & Logs (90-day retention)               │   │
│  └────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Example (Development)

```hcl
module "redis_cache_dev" {
  source = "./modules/azure-redis-cache"

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
    compliance_scope = "Internal"
  }
}
```

### Production Example (High Availability)

```hcl
module "redis_cache_prod" {
  source = "./modules/azure-redis-cache"

  resource_prefix     = "contoso-prod-eastus-banking"
  environment         = "prod"
  location            = "eastus"
  resource_group_name = "rg-contoso-prod-eastus"
  redis_name          = "cache-001"

  # Premium SKU with clustering and zone redundancy
  sku = {
    name     = "Premium"
    family   = "P"
    capacity = 1
  }

  shard_count = 2
  zones       = ["1", "2", "3"]

  # Security Settings
  enable_non_ssl_port           = false
  minimum_tls_version           = "1.2"
  enable_authentication         = true
  aad_authentication_enabled    = true
  public_network_access_enabled = false

  # VNet Injection
  subnet_id = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-network-prod/providers/Microsoft.Network/virtualNetworks/vnet-prod-eastus/subnets/subnet-redis"

  # Private Endpoint
  private_endpoint = {
    enabled              = true
    subnet_id            = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-network-prod/providers/Microsoft.Network/virtualNetworks/vnet-prod-eastus/subnets/subnet-endpoints"
    private_dns_zone_ids = ["/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-dns/providers/Microsoft.Network/privateDnsZones/privatelink.redis.cache.windows.net"]
  }

  # RDB Backup
  rdb_backup_enabled            = true
  rdb_backup_frequency          = 60
  rdb_backup_max_snapshot_count = 7

  # Redis Configuration
  redis_configuration = {
    maxmemory_policy                = "allkeys-lru"
    maxmemory_reserved              = 50
    maxfragmentationmemory_reserved = 50
  }

  # Diagnostics
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

  tags = {
    cost_center      = "CC-67890"
    owner            = "platform-team@contoso.com"
    compliance_scope = "PCI-DSS"
    environment      = "production"
    criticality      = "high"
    backup           = "required"
  }
}
```

## Requirements

| Name | Version |
|------|--------|
| terraform | >= 1.5.0 |
| azurerm | >= 3.80.0, < 4.0.0 |
| random | >= 3.5.0 |

## Providers

| Name | Version |
|------|--------|
| azurerm | >= 3.80.0, < 4.0.0 |

## Resources

| Name | Type |
|------|------|
| azurerm_redis_cache.main | resource |
| azurerm_private_endpoint.redis | resource |
| azurerm_monitor_diagnostic_setting.redis | resource |

## Inputs

### Required Variables

| Name | Description | Type |
|------|-------------|------|
| resource_prefix | Prefix for all resource names following bank's hierarchical naming convention | `string` |
| environment | Environment name (dev, staging, prod) | `string` |
| location | Azure region for Redis Cache deployment | `string` |
| resource_group_name | Name of the existing Azure Resource Group | `string` |
| redis_name | Name of the Redis Cache instance | `string` |
| sku | Redis Cache SKU configuration | `object` |
| tags | Common tags (must include: cost_center, owner, compliance_scope) | `map(string)` |

### Optional Variables

| Name | Description | Type | Default |
|------|-------------|------|--------|
| redis_version | Redis version to deploy | `string` | `"6"` |
| enable_non_ssl_port | Enable non-SSL port (6379) | `bool` | `false` |
| minimum_tls_version | Minimum TLS version | `string` | `"1.2"` |
| shard_count | Number of shards (Premium SKU only) | `number` | `null` |
| zones | Availability zones | `list(string)` | `[]` |
| subnet_id | Subnet ID for VNet injection | `string` | `null` |
| private_endpoint | Private endpoint configuration | `object` | See variables.tf |
| public_network_access_enabled | Enable public network access | `bool` | `false` |
| rdb_backup_enabled | Enable RDB persistence backup | `bool` | `false` |
| rdb_backup_frequency | Backup frequency in minutes | `number` | `60` |
| rdb_backup_max_snapshot_count | Maximum snapshots to retain | `number` | `1` |
| rdb_storage_connection_string | Storage connection string for backups | `string` | `null` |
| redis_configuration | Advanced Redis configuration | `object` | See variables.tf |
| enable_authentication | Require authentication | `bool` | `true` |
| aad_authentication_enabled | Enable Azure AD authentication | `bool` | `false` |
| diagnostic_settings | Diagnostic settings configuration | `object` | See variables.tf |

## Outputs

| Name | Description | Sensitive |
|------|-------------|----------|
| redis_cache_id | Resource ID of the Redis Cache | No |
| redis_cache_name | Name of the Redis Cache | No |
| redis_cache_hostname | Hostname of the Redis Cache | No |
| redis_cache_ssl_port | SSL port (6380) | No |
| redis_cache_port | Non-SSL port (6379) | No |
| redis_primary_access_key | Primary access key | Yes |
| redis_secondary_access_key | Secondary access key | Yes |
| redis_primary_connection_string | Primary connection string | Yes |
| redis_secondary_connection_string | Secondary connection string | Yes |
| redis_private_static_ip_address | Private IP address (VNet injection) | No |
| private_endpoint_id | Private endpoint resource ID | No |

## Security Considerations

### Production Requirements

The module enforces the following security constraints for production environments:

1. **TLS 1.2 Minimum**: `minimum_tls_version` must be "1.2"
2. **SSL Port Only**: `enable_non_ssl_port` must be `false`
3. **Authentication Required**: `enable_authentication` must be `true`
4. **No Public Access**: `public_network_access_enabled` must be `false`
5. **VNet Injection Required**: `subnet_id` must be provided
6. **Mandatory Tags**: Must include `cost_center`, `owner`, `compliance_scope`

### Sensitive Data Handling

- **Access Keys**: Stored in Terraform state (encrypt state files!)
- **Connection Strings**: Marked as sensitive outputs
- **Storage Connection String**: For RDB backups (use Azure Key Vault)

**Recommendations:**
- Store Terraform state in encrypted Azure Storage
- Use Azure Key Vault for secrets management
- Enable Azure AD authentication instead of access keys
- Rotate access keys regularly (90-day cycle)
- Enable audit logging for all Redis operations

## Naming Convention

The module follows a hierarchical naming pattern:

```
Format: <org>-<env>-<region>-<app>-redis-<instance>
Example: contoso-prod-eastus-banking-redis-cache-001
```

### Validation Rules

- 1-63 characters total
- Lowercase letters, numbers, and hyphens only
- Cannot start or end with hyphen
- Must be globally unique across Azure

## SKU Selection Guide

| SKU | Family | Use Case | Max Memory | Clustering | Zone Redundancy | VNet Injection |
|-----|--------|----------|------------|------------|-----------------|----------------|
| Basic | C | Dev/Test | 53 GB | ❌ | ❌ | ❌ |
| Standard | C | Production (small) | 53 GB | ❌ | ❌ | ❌ |
| Premium | P | Production (HA) | 120 GB | ✅ | ✅ | ✅ |

**Recommendation for Banking:** Use Premium SKU for all production workloads.

## High Availability Configuration

### Zone Redundancy

```hcl
sku = {
  name     = "Premium"
  family   = "P"
  capacity = 1
}

zones = ["1", "2", "3"]
```

### Clustering

```hcl
sku = {
  name     = "Premium"
  family   = "P"
  capacity = 1
}

shard_count = 2  # 2-10 shards
```

## Backup Strategy

### RDB Persistence (Premium SKU)

```hcl
rdb_backup_enabled            = true
rdb_backup_frequency          = 60  # Every hour
rdb_backup_max_snapshot_count = 7   # Keep 7 snapshots
rdb_storage_connection_string = "<Azure Storage connection string>"
```

**Backup Frequency Options:**
- 15 minutes
- 30 minutes
- 60 minutes (1 hour)
- 360 minutes (6 hours)
- 720 minutes (12 hours)
- 1440 minutes (24 hours)

## Monitoring and Diagnostics

### Available Log Categories

- `ConnectedClientList`: Track connected clients

### Available Metrics

- `AllMetrics`: All performance metrics (CPU, memory, connections, etc.)

### Example Configuration

```hcl
diagnostic_settings = {
  enabled                    = true
  log_analytics_workspace_id = "<workspace-id>"

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
```

## Testing

The module includes comprehensive unit tests using Terraform's native testing framework.

### Run Tests

```bash
cd tests
terraform init
terraform test
```

### Test Coverage

- ✅ Production security constraints validation
- ✅ Mandatory tags enforcement
- ✅ Naming convention validation
- ✅ SKU configuration validation
- ✅ Backup configuration validation
- ✅ Invalid input rejection

## Semantic Versioning

This module follows [Semantic Versioning 2.0.0](https://semver.org/):

- **MAJOR**: Breaking changes (e.g., removed variables, incompatible type changes)
- **MINOR**: Backward-compatible features (e.g., new optional variables)
- **PATCH**: Backward-compatible bug fixes

**Current Version:** 1.0.0 (Initial Release)

## Migration Guide

### From Unmanaged Redis to This Module

1. **Export existing configuration** using Azure CLI
2. **Map to module variables** (see examples above)
3. **Import existing resource** into Terraform state:
   ```bash
   terraform import module.redis_cache.azurerm_redis_cache.main /subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Cache/redis/{redis-name}
   ```
4. **Run `terraform plan`** to verify no changes
5. **Apply module** for future management

## Compliance and Governance

### Azure Policy Integration

The module is designed to comply with common Azure Policies:

- ✅ **Network Isolation**: VNet injection or Private Endpoint required for production
- ✅ **Encryption**: TLS 1.2 minimum enforced
- ✅ **Authentication**: Access key authentication required
- ✅ **Backup**: RDB backup recommended for Premium SKU
- ✅ **Tagging**: Mandatory tags enforced
- ✅ **Zone Redundancy**: Availability zones for production Premium SKU

### Audit Logging

Enable diagnostic settings to capture:
- Connected client lists
- Performance metrics
- Configuration changes

Retention: 90 days minimum for compliance

## Troubleshooting

### Common Issues

#### 1. Name Already Exists

**Error:** `A resource with the ID already exists`

**Solution:** Redis Cache names must be globally unique. Modify `redis_name` variable.

#### 2. Subnet Not Suitable for VNet Injection

**Error:** `The subnet is not suitable for Redis Cache`

**Solution:** Ensure subnet is delegated to `Microsoft.Cache/redis` and has sufficient IP addresses.

#### 3. Premium SKU Required

**Error:** `Feature only available for Premium SKU`

**Solution:** Clustering, zones, and VNet injection require Premium SKU.

#### 4. Validation Failure in Production

**Error:** `Production environments must use TLS 1.2`

**Solution:** Set `minimum_tls_version = "1.2"` for `environment = "prod"`.

## Support and Contribution

### Reporting Issues

Please report issues through your organization's internal ticketing system.

### Contributing

Contributions must follow:
1. **Code Review**: All changes require peer review
2. **Testing**: Add/update tests for new features
3. **Documentation**: Update README for new variables/outputs
4. **Versioning**: Follow SemVer for version bumps

## License

Internal use only. Proprietary to the organization.

## Authors

- **Platform Engineering Team**
- **Maintained by:** Terraform_Engineer_Agent
- **Contact:** platform-team@contoso.com

## Changelog

### Version 1.0.0 (2025-01-15)

- ✅ Initial release
- ✅ Support for Basic, Standard, and Premium SKUs
- ✅ VNet injection and Private Endpoint support
- ✅ RDB backup configuration
- ✅ Diagnostic settings integration
- ✅ Hierarchical naming convention enforcement
- ✅ Production security validations
- ✅ Comprehensive unit tests

---

**Module Status:** ✅ Production Ready  
**Last Validated:** 2025-01-15  
**Next Review:** 2025-04-15
