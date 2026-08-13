package azure.redis.recovery

import future.keywords.if
import future.keywords.in

# Policy Metadata
policy_id := "AZURE-REDIS-REC-001"
policy_name := "Azure Managed Redis Recovery Mechanism Enforcement"
policy_version := "1.0.0"
severity := "HIGH"
category := "Business Continuity & Disaster Recovery"

# Hard-Mandate: No production Azure Managed Redis instance without an approved recovery mechanism,
# such as data persistence, export-based backup, or active geo-replication
# according to the workload's RPO/RTO requirements.

# Extract all Azure Redis Cache resources from Terraform plan
redis_resources[resource] {
    resource := input.resource_changes[_]
    resource.type == "azurerm_redis_cache"
    resource.change.actions[_] != "delete"
}

# Check if resource is production workload
is_production(resource) if {
    tags := object.get(resource.change.after, "tags", {})
    environment := object.get(tags, "Environment", "")
    environment in ["Production", "Prod", "production", "prod"]
}

# Check if data persistence is enabled (RDB or AOF)
has_data_persistence(resource) if {
    redis_configuration := object.get(resource.change.after, "redis_configuration", {})
    
    # Check for RDB backup
    rdb_backup_enabled := object.get(redis_configuration, "rdb_backup_enabled", "false")
    rdb_backup_enabled == "true"
    
    # Ensure backup frequency and storage are configured
    rdb_backup_frequency := object.get(redis_configuration, "rdb_backup_frequency", "")
    rdb_backup_frequency != ""
    
    rdb_storage_connection_string := object.get(redis_configuration, "rdb_storage_connection_string", "")
    rdb_storage_connection_string != ""
}

has_data_persistence(resource) if {
    redis_configuration := object.get(resource.change.after, "redis_configuration", {})
    
    # Check for AOF (Append-Only File) persistence
    aof_backup_enabled := object.get(redis_configuration, "aof_backup_enabled", "false")
    aof_backup_enabled == "true"
    
    aof_storage_connection_string_0 := object.get(redis_configuration, "aof_storage_connection_string_0", "")
    aof_storage_connection_string_0 != ""
}

# Check if geo-replication is configured
has_geo_replication(resource) if {
    # Check for linked Redis cache (geo-replication)
    linked_server := input.resource_changes[_]
    linked_server.type == "azurerm_redis_linked_server"
    linked_server.change.actions[_] != "delete"
    contains(linked_server.change.after.linked_redis_cache_id, resource.name)
}

# Check if any recovery mechanism is in place
has_recovery_mechanism(resource) if {
    has_data_persistence(resource)
}

has_recovery_mechanism(resource) if {
    has_geo_replication(resource)
}

# Violation: Production Redis without recovery mechanism
violations[violation] {
    resource := redis_resources[_]
    is_production(resource)
    not has_recovery_mechanism(resource)
    
    violation := {
        "policy_id": policy_id,
        "policy_name": policy_name,
        "severity": severity,
        "category": category,
        "resource_type": resource.type,
        "resource_name": resource.name,
        "resource_address": resource.address,
        "violation": "Production Azure Managed Redis instance does not have an approved recovery mechanism configured",
        "rationale": "Production workloads require data recovery capabilities to meet RPO/RTO requirements and ensure business continuity",
        "remediation": sprintf("For Redis instance '%s': Configure one of the following: 1) RDB backup (set rdb_backup_enabled=true, rdb_backup_frequency, rdb_storage_connection_string), 2) AOF persistence (set aof_backup_enabled=true, aof_storage_connection_string_0), or 3) Geo-replication (configure azurerm_redis_linked_server)", [resource.name]),
        "compliant": false,
        "blocking": true
    }
}

# Warning: RDB backup configured but frequency may not meet RPO
violations[violation] {
    resource := redis_resources[_]
    is_production(resource)
    
    redis_configuration := object.get(resource.change.after, "redis_configuration", {})
    rdb_backup_enabled := object.get(redis_configuration, "rdb_backup_enabled", "false")
    rdb_backup_enabled == "true"
    
    rdb_backup_frequency := object.get(redis_configuration, "rdb_backup_frequency", "")
    # Frequency should be at least 60 minutes for production
    to_number(rdb_backup_frequency) > 60
    
    violation := {
        "policy_id": policy_id,
        "policy_name": policy_name,
        "severity": "MEDIUM",
        "category": category,
        "resource_type": resource.type,
        "resource_name": resource.name,
        "resource_address": resource.address,
        "violation": sprintf("Production Redis RDB backup frequency (%s minutes) may not meet typical RPO requirements", [rdb_backup_frequency]),
        "rationale": "Production workloads typically require backup frequency of 60 minutes or less to minimize data loss",
        "remediation": sprintf("For Redis instance '%s': Review RPO requirements and consider reducing rdb_backup_frequency to 15, 30, or 60 minutes", [resource.name]),
        "compliant": false,
        "blocking": false
    }
}

# Compliance decision
deny[msg] {
    blocking_violations := [v | v := violations[_]; v.blocking == true]
    count(blocking_violations) > 0
    msg := sprintf("BLOCK: %d Azure Redis instance(s) violate recovery mechanism policy", [count(blocking_violations)])
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
