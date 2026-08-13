package azure.redis.tls_config

import future.keywords.if
import future.keywords.in

# Policy Metadata
policy_id := "AZURE-REDIS-TLS-001"
policy_name := "Azure Managed Redis TLS Configuration Enforcement"
policy_version := "1.0.0"
severity := "CRITICAL"
category := "Encryption in Transit"

# Hard-Mandate: No Azure Managed Redis instance using non-TLS or outdated TLS configuration;
# secure TLS connectivity must be enforced.

# Extract all Azure Redis Cache resources from Terraform plan
redis_resources[resource] {
    resource := input.resource_changes[_]
    resource.type == "azurerm_redis_cache"
    resource.change.actions[_] != "delete"
}

# Check if non-TLS port is disabled (port 6379)
has_non_ssl_disabled(resource) if {
    enable_non_ssl_port := object.get(resource.change.after, "enable_non_ssl_port", true)
    enable_non_ssl_port == false
}

# Check if minimum TLS version is 1.2 or higher
has_secure_tls_version(resource) if {
    minimum_tls_version := object.get(resource.change.after, "minimum_tls_version", "1.0")
    minimum_tls_version in ["1.2", "1.3"]
}

# Violation: Non-SSL port is enabled
violations[violation] {
    resource := redis_resources[_]
    not has_non_ssl_disabled(resource)
    
    violation := {
        "policy_id": policy_id,
        "policy_name": policy_name,
        "severity": severity,
        "category": category,
        "resource_type": resource.type,
        "resource_name": resource.name,
        "resource_address": resource.address,
        "violation": "Azure Managed Redis instance has non-SSL port (6379) enabled",
        "rationale": "Non-TLS connections expose data in transit to interception and tampering; all connections must use TLS encryption",
        "remediation": sprintf("For Redis instance '%s': Set 'enable_non_ssl_port = false' to disable unencrypted connections on port 6379", [resource.name]),
        "compliant": false,
        "blocking": true
    }
}

# Violation: TLS version is outdated (< 1.2)
violations[violation] {
    resource := redis_resources[_]
    not has_secure_tls_version(resource)
    
    minimum_tls_version := object.get(resource.change.after, "minimum_tls_version", "1.0")
    
    violation := {
        "policy_id": policy_id,
        "policy_name": policy_name,
        "severity": severity,
        "category": category,
        "resource_type": resource.type,
        "resource_name": resource.name,
        "resource_address": resource.address,
        "violation": sprintf("Azure Managed Redis instance uses outdated TLS version: %s", [minimum_tls_version]),
        "rationale": "TLS versions below 1.2 have known vulnerabilities and are not compliant with modern security standards",
        "remediation": sprintf("For Redis instance '%s': Set 'minimum_tls_version = \"1.2\"' (or \"1.3\" for enhanced security)", [resource.name]),
        "compliant": false,
        "blocking": true
    }
}

# Compliance decision
deny[msg] {
    count(violations) > 0
    msg := sprintf("BLOCK: %d Azure Redis instance(s) violate TLS configuration policy", [count(violations)])
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
