package azure.redis.entra_auth

import future.keywords.if
import future.keywords.in

# Policy Metadata
policy_id := "AZURE-REDIS-AUTH-001"
policy_name := "Azure Managed Redis Entra ID Authentication Enforcement"
policy_version := "1.0.0"
severity := "CRITICAL"
category := "Authentication & Access Control"

# Hard-Mandate: No Azure Managed Redis instance relying on access-key authentication
# where Microsoft Entra ID authentication is mandated;
# access-key authentication must be disabled after Entra authentication is configured.

# Extract all Azure Redis Cache resources from Terraform plan
redis_resources[resource] {
    resource := input.resource_changes[_]
    resource.type == "azurerm_redis_cache"
    resource.change.actions[_] != "delete"
}

# Check if resource requires Entra ID authentication (production/regulated)
is_production_or_regulated(resource) if {
    tags := object.get(resource.change.after, "tags", {})
    environment := object.get(tags, "Environment", "")
    environment in ["Production", "Prod", "production", "prod", "Regulated", "regulated"]
}

is_production_or_regulated(resource) if {
    tags := object.get(resource.change.after, "tags", {})
    data_classification := object.get(tags, "DataClassification", "")
    data_classification in ["Confidential", "Restricted", "HighlyConfidential", "PII", "PHI"]
}

# Check if Entra ID (AAD) authentication is enabled
has_entra_auth_enabled(resource) if {
    # Azure Redis Enterprise supports AAD authentication via aad_enabled
    aad_enabled := object.get(resource.change.after, "aad_enabled", false)
    aad_enabled == true
}

has_entra_auth_enabled(resource) if {
    # Check for Azure Cache for Redis Enterprise with active_directory_authentication_enabled
    active_directory_authentication_enabled := object.get(resource.change.after, "active_directory_authentication_enabled", false)
    active_directory_authentication_enabled == true
}

# Check if access keys are disabled
has_access_keys_disabled(resource) if {
    # Redis access keys authentication disabled
    redis_configuration := object.get(resource.change.after, "redis_configuration", {})
    aad_enabled := object.get(redis_configuration, "aad_enabled", "false")
    aad_enabled == "true"
    
    # When AAD is enabled, access key auth should be disabled
    enable_authentication := object.get(redis_configuration, "enable_authentication", "true")
    enable_authentication == "false"
}

has_access_keys_disabled(resource) if {
    # For Enterprise tier with disable_access_key_authentication
    disable_access_key_authentication := object.get(resource.change.after, "disable_access_key_authentication", false)
    disable_access_key_authentication == true
}

# Violation: Production/Regulated Redis without Entra ID authentication
violations[violation] {
    resource := redis_resources[_]
    is_production_or_regulated(resource)
    not has_entra_auth_enabled(resource)
    
    violation := {
        "policy_id": policy_id,
        "policy_name": policy_name,
        "severity": severity,
        "category": category,
        "resource_type": resource.type,
        "resource_name": resource.name,
        "resource_address": resource.address,
        "violation": "Azure Managed Redis instance does not have Microsoft Entra ID authentication enabled",
        "rationale": "Production and regulated workloads must use Entra ID (Azure AD) authentication for centralized identity management and enhanced security",
        "remediation": sprintf("For Redis instance '%s': 1) Upgrade to Premium or Enterprise tier if needed, 2) Enable Entra ID authentication (set 'aad_enabled = true' or 'active_directory_authentication_enabled = true'), 3) Configure managed identity, 4) Disable access key authentication", [resource.name]),
        "compliant": false,
        "blocking": true
    }
}

# Violation: Entra ID enabled but access keys not disabled
violations[violation] {
    resource := redis_resources[_]
    is_production_or_regulated(resource)
    has_entra_auth_enabled(resource)
    not has_access_keys_disabled(resource)
    
    violation := {
        "policy_id": policy_id,
        "policy_name": policy_name,
        "severity": "HIGH",
        "category": category,
        "resource_type": resource.type,
        "resource_name": resource.name,
        "resource_address": resource.address,
        "violation": "Azure Managed Redis has Entra ID authentication enabled but access-key authentication is not disabled",
        "rationale": "Access keys provide an alternative authentication path that bypasses Entra ID controls; they must be disabled when Entra ID is mandated",
        "remediation": sprintf("For Redis instance '%s': Set 'disable_access_key_authentication = true' or configure redis_configuration with 'enable_authentication = false' after Entra ID is configured", [resource.name]),
        "compliant": false,
        "blocking": true
    }
}

# Compliance decision
deny[msg] {
    count(violations) > 0
    msg := sprintf("BLOCK: %d Azure Redis instance(s) violate Entra ID authentication policy", [count(violations)])
}

# Summary for certificate
summary := {
    "policy_id": policy_id,
    "policy_name": policy_name,
    "policy_version": policy_version,
    "severity": severity,
    "total_violations": count(violations),
    "compliant": count(violations) == 0,
    "violations": violations
}
