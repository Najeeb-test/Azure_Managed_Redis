# =============================================================================
# ADDITIONAL UNIT TESTS FOR VARIABLE VALIDATIONS
# Focus: Azure Region Codes and CIDR Range Validations
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
# AZURE REGION VALIDATION TESTS
# =============================================================================

# TEST: Valid Azure region (lowercase)
run "valid_azure_region_lowercase" {
  command = plan

  variables {
    location = "eastus"
  }

  assert {
    condition     = can(regex("^[a-z]+$", var.location))
    error_message = "Location validation should pass for valid lowercase region."
  }
}

# TEST: Valid Azure region (different region)
run "valid_azure_region_westeurope" {
  command = plan

  variables {
    location = "westeurope"
  }

  assert {
    condition     = can(regex("^[a-z]+$", var.location))
    error_message = "Location validation should pass for westeurope."
  }
}

# TEST: Invalid Azure region (contains uppercase)
run "expect_failure_invalid_region_uppercase" {
  command = plan

  variables {
    location = "EastUS" # Invalid: must be lowercase
  }

  expect_failures = [
    var.location
  ]
}

# TEST: Invalid Azure region (contains numbers)
run "expect_failure_invalid_region_with_numbers" {
  command = plan

  variables {
    location = "eastus2" # Invalid: contains numbers
  }

  expect_failures = [
    var.location
  ]
}

# TEST: Invalid Azure region (contains hyphens)
run "expect_failure_invalid_region_with_hyphens" {
  command = plan

  variables {
    location = "east-us" # Invalid: contains hyphens
  }

  expect_failures = [
    var.location
  ]
}

# TEST: Invalid Azure region (empty string)
run "expect_failure_invalid_region_empty" {
  command = plan

  variables {
    location = "" # Invalid: empty string
  }

  expect_failures = [
    var.location
  ]
}

# TEST: Invalid Azure region (special characters)
run "expect_failure_invalid_region_special_chars" {
  command = plan

  variables {
    location = "east_us" # Invalid: contains underscore
  }

  expect_failures = [
    var.location
  ]
}

# =============================================================================
# SUBNET ID (CIDR-RELATED) VALIDATION TESTS
# Note: The module validates subnet_id format, not CIDR directly
# =============================================================================

# TEST: Valid subnet ID format
run "valid_subnet_id_format" {
  command = plan

  variables {
    subnet_id = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-prod/subnets/subnet-redis"
  }

  assert {
    condition     = can(regex("^/subscriptions/.+/resourceGroups/.+/providers/Microsoft.Network/virtualNetworks/.+/subnets/.+$", var.subnet_id))
    error_message = "Subnet ID validation should pass for valid format."
  }
}

# TEST: Invalid subnet ID format (missing subscription)
run "expect_failure_invalid_subnet_id_missing_subscription" {
  command = plan

  variables {
    subnet_id = "/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-prod/subnets/subnet-redis"
  }

  expect_failures = [
    var.subnet_id
  ]
}

# TEST: Invalid subnet ID format (wrong provider)
run "expect_failure_invalid_subnet_id_wrong_provider" {
  command = plan

  variables {
    subnet_id = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-network/providers/Microsoft.Compute/virtualNetworks/vnet-prod/subnets/subnet-redis"
  }

  expect_failures = [
    var.subnet_id
  ]
}

# TEST: Invalid subnet ID format (malformed)
run "expect_failure_invalid_subnet_id_malformed" {
  command = plan

  variables {
    subnet_id = "invalid-subnet-id"
  }

  expect_failures = [
    var.subnet_id
  ]
}

# TEST: Null subnet ID in dev environment (should be allowed)
run "valid_null_subnet_id_dev" {
  command = plan

  variables {
    environment = "dev"
    subnet_id   = null
  }

  assert {
    condition     = var.subnet_id == null
    error_message = "Null subnet ID should be allowed in dev environment."
  }
}

# =============================================================================
# RESOURCE PREFIX VALIDATION TESTS
# =============================================================================

# TEST: Valid resource prefix (4 segments)
run "valid_resource_prefix_4_segments" {
  command = plan

  variables {
    resource_prefix = "org-dev-eastus-app"
  }

  assert {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+){3,}$", var.resource_prefix))
    error_message = "Resource prefix validation should pass for 4 segments."
  }
}

# TEST: Valid resource prefix (5 segments)
run "valid_resource_prefix_5_segments" {
  command = plan

  variables {
    resource_prefix = "contoso-prod-westus-banking-core"
  }

  assert {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+){3,}$", var.resource_prefix))
    error_message = "Resource prefix validation should pass for 5 segments."
  }
}

# TEST: Invalid resource prefix (only 3 segments)
run "expect_failure_resource_prefix_3_segments" {
  command = plan

  variables {
    resource_prefix = "org-dev-app" # Invalid: only 3 segments
  }

  expect_failures = [
    var.resource_prefix
  ]
}

# TEST: Invalid resource prefix (contains uppercase)
run "expect_failure_resource_prefix_uppercase" {
  command = plan

  variables {
    resource_prefix = "Contoso-Dev-EastUS-Banking" # Invalid: contains uppercase
  }

  expect_failures = [
    var.resource_prefix
  ]
}

# TEST: Invalid resource prefix (contains underscores)
run "expect_failure_resource_prefix_underscores" {
  command = plan

  variables {
    resource_prefix = "contoso_dev_eastus_banking" # Invalid: contains underscores
  }

  expect_failures = [
    var.resource_prefix
  ]
}

# TEST: Invalid resource prefix (starts with hyphen)
run "expect_failure_resource_prefix_starts_hyphen" {
  command = plan

  variables {
    resource_prefix = "-contoso-dev-eastus-banking" # Invalid: starts with hyphen
  }

  expect_failures = [
    var.resource_prefix
  ]
}

# TEST: Invalid resource prefix (ends with hyphen)
run "expect_failure_resource_prefix_ends_hyphen" {
  command = plan

  variables {
    resource_prefix = "contoso-dev-eastus-banking-" # Invalid: ends with hyphen
  }

  expect_failures = [
    var.resource_prefix
  ]
}

# =============================================================================
# RESOURCE GROUP NAME VALIDATION TESTS
# =============================================================================

# TEST: Valid resource group name (minimum length)
run "valid_resource_group_name_min_length" {
  command = plan

  variables {
    resource_group_name = "a" # 1 character (minimum)
  }

  assert {
    condition     = length(var.resource_group_name) >= 1 && length(var.resource_group_name) <= 90
    error_message = "Resource group name validation should pass for minimum length."
  }
}

# TEST: Valid resource group name (maximum length)
run "valid_resource_group_name_max_length" {
  command = plan

  variables {
    resource_group_name = "rg-${
      join("", [for i in range(86) : "a"])
    }" # 90 characters (maximum)
  }

  assert {
    condition     = length(var.resource_group_name) <= 90
    error_message = "Resource group name validation should pass for maximum length."
  }
}

# TEST: Invalid resource group name (empty)
run "expect_failure_resource_group_name_empty" {
  command = plan

  variables {
    resource_group_name = "" # Invalid: empty string
  }

  expect_failures = [
    var.resource_group_name
  ]
}

# TEST: Invalid resource group name (exceeds 90 characters)
run "expect_failure_resource_group_name_too_long" {
  command = plan

  variables {
    resource_group_name = "rg-${
      join("", [for i in range(88) : "a"])
    }" # 91 characters (exceeds maximum)
  }

  expect_failures = [
    var.resource_group_name
  ]
}

# =============================================================================
# SKU CAPACITY VALIDATION TESTS
# =============================================================================

# TEST: Valid SKU capacity (minimum)
run "valid_sku_capacity_min" {
  command = plan

  variables {
    sku = {
      name     = "Basic"
      family   = "C"
      capacity = 0 # Minimum capacity
    }
  }

  assert {
    condition     = var.sku.capacity >= 0 && var.sku.capacity <= 6
    error_message = "SKU capacity validation should pass for minimum value."
  }
}

# TEST: Valid SKU capacity (maximum)
run "valid_sku_capacity_max" {
  command = plan

  variables {
    sku = {
      name     = "Standard"
      family   = "C"
      capacity = 6 # Maximum capacity
    }
  }

  assert {
    condition     = var.sku.capacity >= 0 && var.sku.capacity <= 6
    error_message = "SKU capacity validation should pass for maximum value."
  }
}

# TEST: Invalid SKU capacity (negative)
run "expect_failure_sku_capacity_negative" {
  command = plan

  variables {
    sku = {
      name     = "Standard"
      family   = "C"
      capacity = -1 # Invalid: negative capacity
    }
  }

  expect_failures = [
    var.sku
  ]
}

# TEST: Invalid SKU capacity (exceeds maximum)
run "expect_failure_sku_capacity_exceeds_max" {
  command = plan

  variables {
    sku = {
      name     = "Standard"
      family   = "C"
      capacity = 7 # Invalid: exceeds maximum
    }
  }

  expect_failures = [
    var.sku
  ]
}

# =============================================================================
# RDB BACKUP FREQUENCY VALIDATION TESTS
# =============================================================================

# TEST: Valid RDB backup frequency (15 minutes)
run "valid_rdb_backup_frequency_15" {
  command = plan

  variables {
    sku = {
      name     = "Premium"
      family   = "P"
      capacity = 1
    }
    rdb_backup_enabled   = true
    rdb_backup_frequency = 15
  }

  assert {
    condition     = contains([15, 30, 60, 360, 720, 1440], var.rdb_backup_frequency)
    error_message = "RDB backup frequency validation should pass for 15 minutes."
  }
}

# TEST: Valid RDB backup frequency (1440 minutes)
run "valid_rdb_backup_frequency_1440" {
  command = plan

  variables {
    sku = {
      name     = "Premium"
      family   = "P"
      capacity = 1
    }
    rdb_backup_enabled   = true
    rdb_backup_frequency = 1440
  }

  assert {
    condition     = contains([15, 30, 60, 360, 720, 1440], var.rdb_backup_frequency)
    error_message = "RDB backup frequency validation should pass for 1440 minutes."
  }
}

# TEST: Invalid RDB backup frequency (45 minutes)
run "expect_failure_rdb_backup_frequency_invalid" {
  command = plan

  variables {
    sku = {
      name     = "Premium"
      family   = "P"
      capacity = 1
    }
    rdb_backup_enabled   = true
    rdb_backup_frequency = 45 # Invalid: not in allowed list
  }

  expect_failures = [
    var.rdb_backup_frequency
  ]
}
