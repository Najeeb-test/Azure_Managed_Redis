package azure.redis.public_access

import future.keywords.if
import future.keywords.in

# Policy Metadata
policy_id := "AZURE-REDIS-NET-001"
policy_name := "Azure Managed Redis Public Network Access Restriction"
policy_version := "1.0.0"
severity := "CRITICAL"
category := "Network Security"

# Hard-Mandate: No Azure Managed Redis instance with public network access enabled
# for production or regulated workloads; Private Endpoint and private connectivity must be configured.

# Extract all Azure Redis Cache resources from Terraform plan
redis_resources[resource] {
    resource := input.resource_changes[_]
    resource.type == "azurerm_redis_cache"
    resource.change.actions[_] != "delete"
}

# Check if resource is production or regulated workload
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

# Check if public network access is disabled
has_public_access_disabled(resource) if {
    public_network_access_enabled := object.get(resource.change.after, "public_network_access_enabled", true)
    public_network_access_enabled == false
}

# Check if private endpoint is configured (via separate resource)
private_endpoints[pe] {
    pe := input.resource_changes[_]
    pe.type == "azurerm_private_endpoint"
    pe.change.actions[_] != "delete"
}

has_private_endpoint(resource) if {
    pe := private_endpoints[_]
    # Check if private endpoint references this Redis instance
    contains(pe.change.after.private_service_connection[_].private_connection_resource_id, resource.name)
}

# Violation: Production/Regulated Redis with public access enabled
violations[violation] {
    resource := redis_resources[_]
    is_production_or_regulated(resource)
    not has_public_access_disabled(resource)
    
    violation := {
        "policy_id": policy_id,
        "policy_name": policy_name,
        "severity": severity,
        "category": category,
        "resource_type": resource.type,
        "resource_name": resource.name,
        "resource_address": resource.address,
        "violation": "Azure Managed Redis instance has public network access enabled for production/regulated workload",
        "rationale": "Production and regulated workloads must use private connectivity only to prevent unauthorized external access",
        "remediation": sprintf("For Redis instance '%s': 1) Set 'public_network_access_enabled = false', 2) Configure Azure Private Endpoint, 3) Ensure private DNS zone integration for name resolution", [resource.name]),
        "compliant": false,
        "blocking": true
    }
}

# Additional violation: No private endpoint configured when public access is disabled
violations[violation] {
    resource := redis_resources[_]
    is_production_or_regulated(resource)
    has_public_access_disabled(resource)
    not has_private_endpoint(resource)
    
    violation := {
        "policy_id": policy_id,
        "policy_name": policy_name,
        "severity": "HIGH",
        "category": category,
        "resource_type": resource.type,
        "resource_name": resource.name,
        "resource_address": resource.address,
        "violation": "Azure Managed Redis instance has public access disabled but no Private Endpoint configured",
        "rationale": "Private connectivity requires both disabling public access AND configuring Private Endpoint for secure access",
        "remediation": sprintf("For Redis instance '%s': Configure Azure Private Endpoint resource (azurerm_private_endpoint) with private_service_connection pointing to this Redis instance", [resource.name]),
        "compliant": false,
        "blocking": true
    }
}

# Compliance decision
deny[msg] {
    count(violations) > 0
    msg := sprintf("BLOCK: %d Azure Redis instance(s) violate public network access policy", [count(violations)])
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
