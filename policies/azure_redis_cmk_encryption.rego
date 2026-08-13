package azure.redis.cmk_encryption

import future.keywords.if
import future.keywords.in

# Policy Metadata
policy_id := "AZURE-REDIS-CMK-001"
policy_name := "Azure Managed Redis CMK Encryption Enforcement"
policy_version := "1.0.0"
severity := "CRITICAL"
category := "Encryption"

# Hard-Mandate: No Azure Managed Redis instance without Customer-Managed Key (CMK) encryption
# where the bank's data-classification policy requires customer-controlled encryption keys.

# Extract all Azure Redis Cache resources from Terraform plan
redis_resources[resource] {
    resource := input.resource_changes[_]
    resource.type == "azurerm_redis_cache"
    resource.change.actions[_] != "delete"
}

# Check if resource has high data classification requiring CMK
requires_cmk(resource) if {
    tags := object.get(resource.change.after, "tags", {})
    data_classification := object.get(tags, "DataClassification", "")
    data_classification in ["Confidential", "Restricted", "HighlyConfidential", "PII", "PHI"]
}

requires_cmk(resource) if {
    tags := object.get(resource.change.after, "tags", {})
    environment := object.get(tags, "Environment", "")
    environment in ["Production", "Prod", "production", "prod"]
}

# Check if CMK encryption is properly configured
has_cmk_encryption(resource) if {
    identity := object.get(resource.change.after, "identity", [])
    count(identity) > 0
    identity[0].type in ["SystemAssigned", "UserAssigned", "SystemAssigned, UserAssigned"]
    
    encryption := object.get(resource.change.after, "encryption", [])
    count(encryption) > 0
    encryption[0].key_vault_key_id != null
    encryption[0].key_vault_key_id != ""
}

# Violation: Redis requires CMK but doesn't have it configured
violations[violation] {
    resource := redis_resources[_]
    requires_cmk(resource)
    not has_cmk_encryption(resource)
    
    violation := {
        "policy_id": policy_id,
        "policy_name": policy_name,
        "severity": severity,
        "category": category,
        "resource_type": resource.type,
        "resource_name": resource.name,
        "resource_address": resource.address,
        "violation": "Azure Managed Redis instance does not have Customer-Managed Key (CMK) encryption configured",
        "rationale": "Bank's data-classification policy requires customer-controlled encryption keys for production and sensitive data workloads",
        "remediation": sprintf("Configure CMK encryption for Redis instance '%s' by: 1) Enable managed identity (SystemAssigned or UserAssigned), 2) Create/reference Azure Key Vault key, 3) Add encryption block with key_vault_key_id", [resource.name]),
        "compliant": false,
        "blocking": true
    }
}

# Compliance decision
deny[msg] {
    count(violations) > 0
    msg := sprintf("BLOCK: %d Azure Redis instance(s) violate CMK encryption policy", [count(violations)])
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
