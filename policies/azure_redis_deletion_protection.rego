package azure.redis.deletion_protection

import future.keywords.if
import future.keywords.in

# Policy Metadata
policy_id := "AZURE-REDIS-DEL-001"
policy_name := "Azure Managed Redis Deletion Protection Enforcement"
policy_version := "1.0.0"
severity := "HIGH"
category := "Resource Protection"

# Hard-Mandate: No production or critical Azure Managed Redis instance without deletion protection,
# implemented through an Azure CanNotDelete resource lock where required by policy.

# Extract all Azure Redis Cache resources from Terraform plan
redis_resources[resource] {
    resource := input.resource_changes[_]
    resource.type == "azurerm_redis_cache"
    resource.change.actions[_] != "delete"
}

# Extract all Management Locks from Terraform plan
management_locks[lock] {
    lock := input.resource_changes[_]
    lock.type == "azurerm_management_lock"
    lock.change.actions[_] != "delete"
}

# Check if resource is production or critical
is_production_or_critical(resource) if {
    tags := object.get(resource.change.after, "tags", {})
    environment := object.get(tags, "Environment", "")
    environment in ["Production", "Prod", "production", "prod"]
}

is_production_or_critical(resource) if {
    tags := object.get(resource.change.after, "tags", {})
    criticality := object.get(tags, "Criticality", "")
    criticality in ["Critical", "High", "critical", "high"]
}

is_production_or_critical(resource) if {
    tags := object.get(resource.change.after, "tags", {})
    data_classification := object.get(tags, "DataClassification", "")
    data_classification in ["Confidential", "Restricted", "HighlyConfidential"]
}

# Check if CanNotDelete lock exists for the Redis resource
has_cannot_delete_lock(resource) if {
    lock := management_locks[_]
    lock.change.after.lock_level == "CanNotDelete"
    
    # Check if lock scope matches Redis resource
    # Lock scope should reference the Redis cache resource ID
    scope := lock.change.after.scope
    contains(scope, resource.name)
}

has_cannot_delete_lock(resource) if {
    lock := management_locks[_]
    lock.change.after.lock_level == "CanNotDelete"
    
    # Alternative: check if lock name references the Redis resource
    lock_name := lock.change.after.name
    contains(lock_name, resource.name)
}

# Violation: Production/Critical Redis without CanNotDelete lock
violations[violation] {
    resource := redis_resources[_]
    is_production_or_critical(resource)
    not has_cannot_delete_lock(resource)
    
    violation := {
        "policy_id": policy_id,
        "policy_name": policy_name,
        "severity": severity,
        "category": category,
        "resource_type": resource.type,
        "resource_name": resource.name,
        "resource_address": resource.address,
        "violation": "Production/Critical Azure Managed Redis instance does not have CanNotDelete resource lock configured",
        "rationale": "Deletion protection prevents accidental or unauthorized deletion of critical production resources",
        "remediation": sprintf("For Redis instance '%s': Create an azurerm_management_lock resource with lock_level = 'CanNotDelete' and scope pointing to this Redis instance's resource ID", [resource.name]),
        "compliant": false,
        "blocking": true
    }
}

# Compliance decision
deny[msg] {
    count(violations) > 0
    msg := sprintf("BLOCK: %d Azure Redis instance(s) violate deletion protection policy", [count(violations)])
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
