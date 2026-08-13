package azure.redis.diagnostic_logging

import future.keywords.if
import future.keywords.in

# Policy Metadata
policy_id := "AZURE-REDIS-LOG-001"
policy_name := "Azure Managed Redis Diagnostic Logging and Monitoring Enforcement"
policy_version := "1.0.0"
severity := "HIGH"
category := "Monitoring & Logging"

# Hard-Mandate: No Azure Managed Redis deployment without required diagnostic logging
# and monitoring for production/regulated workloads

# Extract all Azure Redis Cache resources from Terraform plan
redis_resources[resource] {
    resource := input.resource_changes[_]
    resource.type == "azurerm_redis_cache"
    resource.change.actions[_] != "delete"
}

# Extract all Monitor Diagnostic Settings from Terraform plan
diagnostic_settings[setting] {
    setting := input.resource_changes[_]
    setting.type == "azurerm_monitor_diagnostic_setting"
    setting.change.actions[_] != "delete"
}

# Check if resource is production or regulated
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

# Required log categories for Redis
required_log_categories := [
    "ConnectedClientList"
]

# Required metric categories
required_metrics := [
    "AllMetrics"
]

# Check if diagnostic setting exists for Redis resource
has_diagnostic_setting(resource) if {
    setting := diagnostic_settings[_]
    target_resource_id := setting.change.after.target_resource_id
    contains(target_resource_id, resource.name)
}

has_diagnostic_setting(resource) if {
    setting := diagnostic_settings[_]
    setting_name := setting.change.after.name
    contains(setting_name, resource.name)
}

# Check if diagnostic setting has required log categories enabled
has_required_logs(resource) if {
    setting := diagnostic_settings[_]
    target_resource_id := setting.change.after.target_resource_id
    contains(target_resource_id, resource.name)
    
    enabled_logs := setting.change.after.enabled_log
    
    # Check if all required categories are enabled
    required_log_categories[_] == enabled_logs[_].category
    enabled_logs[_].enabled == true
}

has_required_logs(resource) if {
    setting := diagnostic_settings[_]
    target_resource_id := setting.change.after.target_resource_id
    contains(target_resource_id, resource.name)
    
    log_settings := setting.change.after.log
    
    # Alternative structure: log blocks
    log_settings[_].category in required_log_categories
    log_settings[_].enabled == true
}

# Check if diagnostic setting has metrics enabled
has_metrics_enabled(resource) if {
    setting := diagnostic_settings[_]
    target_resource_id := setting.change.after.target_resource_id
    contains(target_resource_id, resource.name)
    
    metric_settings := setting.change.after.metric
    metric_settings[_].category == "AllMetrics"
    metric_settings[_].enabled == true
}

# Check if logs are sent to appropriate destination
has_log_destination(resource) if {
    setting := diagnostic_settings[_]
    target_resource_id := setting.change.after.target_resource_id
    contains(target_resource_id, resource.name)
    
    # At least one destination must be configured
    log_analytics_workspace_id := object.get(setting.change.after, "log_analytics_workspace_id", "")
    storage_account_id := object.get(setting.change.after, "storage_account_id", "")
    eventhub_authorization_rule_id := object.get(setting.change.after, "eventhub_authorization_rule_id", "")
    
    # At least one must be non-empty
    any([log_analytics_workspace_id != "", storage_account_id != "", eventhub_authorization_rule_id != ""])
}

# Violation: No diagnostic setting configured
violations[violation] {
    resource := redis_resources[_]
    is_production_or_regulated(resource)
    not has_diagnostic_setting(resource)
    
    violation := {
        "policy_id": policy_id,
        "policy_name": policy_name,
        "severity": severity,
        "category": category,
        "resource_type": resource.type,
        "resource_name": resource.name,
        "resource_address": resource.address,
        "violation": "Production/Regulated Azure Managed Redis instance does not have diagnostic settings configured",
        "rationale": "Diagnostic logging is mandatory for security monitoring, compliance, troubleshooting, and audit trail requirements",
        "remediation": sprintf("For Redis instance '%s': Create azurerm_monitor_diagnostic_setting resource with target_resource_id pointing to this Redis instance, enable required log categories (ConnectedClientList) and AllMetrics, and configure destination (Log Analytics, Storage Account, or Event Hub)", [resource.name]),
        "compliant": false,
        "blocking": true
    }
}

# Violation: Diagnostic setting exists but missing required logs
violations[violation] {
    resource := redis_resources[_]
    is_production_or_regulated(resource)
    has_diagnostic_setting(resource)
    not has_required_logs(resource)
    
    violation := {
        "policy_id": policy_id,
        "policy_name": policy_name,
        "severity": severity,
        "category": category,
        "resource_type": resource.type,
        "resource_name": resource.name,
        "resource_address": resource.address,
        "violation": sprintf("Azure Managed Redis diagnostic setting is missing required log categories: %v", [required_log_categories]),
        "rationale": "Required log categories must be enabled for comprehensive security and operational monitoring",
        "remediation": sprintf("For Redis instance '%s': Update diagnostic setting to enable log categories: %v with enabled = true", [resource.name, required_log_categories]),
        "compliant": false,
        "blocking": true
    }
}

# Violation: Diagnostic setting exists but metrics not enabled
violations[violation] {
    resource := redis_resources[_]
    is_production_or_regulated(resource)
    has_diagnostic_setting(resource)
    not has_metrics_enabled(resource)
    
    violation := {
        "policy_id": policy_id,
        "policy_name": policy_name,
        "severity": "MEDIUM",
        "category": category,
        "resource_type": resource.type,
        "resource_name": resource.name,
        "resource_address": resource.address,
        "violation": "Azure Managed Redis diagnostic setting does not have AllMetrics enabled",
        "rationale": "Metrics are essential for performance monitoring, capacity planning, and proactive issue detection",
        "remediation": sprintf("For Redis instance '%s': Update diagnostic setting to enable metric category 'AllMetrics' with enabled = true", [resource.name]),
        "compliant": false,
        "blocking": false
    }
}

# Violation: Diagnostic setting exists but no destination configured
violations[violation] {
    resource := redis_resources[_]
    is_production_or_regulated(resource)
    has_diagnostic_setting(resource)
    not has_log_destination(resource)
    
    violation := {
        "policy_id": policy_id,
        "policy_name": policy_name,
        "severity": severity,
        "category": category,
        "resource_type": resource.type,
        "resource_name": resource.name,
        "resource_address": resource.address,
        "violation": "Azure Managed Redis diagnostic setting has no destination configured for logs/metrics",
        "rationale": "Logs and metrics must be sent to a destination (Log Analytics, Storage Account, or Event Hub) for retention and analysis",
        "remediation": sprintf("For Redis instance '%s': Configure at least one destination in diagnostic setting: log_analytics_workspace_id, storage_account_id, or eventhub_authorization_rule_id", [resource.name]),
        "compliant": false,
        "blocking": true
    }
}

# Compliance decision
deny[msg] {
    blocking_violations := [v | v := violations[_]; v.blocking == true]
    count(blocking_violations) > 0
    msg := sprintf("BLOCK: %d Azure Redis instance(s) violate diagnostic logging and monitoring policy", [count(blocking_violations)])
}

# Summary for certificate
summary := {
    "policy_id": policy_id,
    "policy_name": policy_name,
    "policy_version": policy_version,
    "severity": severity,
    "total_violations": count(violations),
    "compliant": count(violations) == 0,
    "violations": violations,
    "required_log_categories": required_log_categories,
    "required_metrics": required_metrics
}
