package azure.redis.rbac_least_privilege

import future.keywords.if
import future.keywords.in

# Policy Metadata
policy_id := "AZURE-REDIS-RBAC-001"
policy_name := "Azure Managed Redis RBAC Least Privilege Enforcement"
policy_version := "1.0.0"
severity := "HIGH"
category := "Access Control & Authorization"

# Hard-Mandate: No Azure Managed Redis deployment with excessive Azure RBAC permissions;
# access must follow least privilege.

# Extract all Azure Redis Cache resources from Terraform plan
redis_resources[resource] {
    resource := input.resource_changes[_]
    resource.type == "azurerm_redis_cache"
    resource.change.actions[_] != "delete"
}

# Extract all role assignments from Terraform plan
role_assignments[assignment] {
    assignment := input.resource_changes[_]
    assignment.type == "azurerm_role_assignment"
    assignment.change.actions[_] != "delete"
}

# Prohibited high-privilege roles for Redis resources
prohibited_roles := [
    "Owner",
    "Contributor",
    "User Access Administrator"
]

# Approved least-privilege roles for Redis
approved_redis_roles := [
    "Redis Cache Contributor",
    "Reader",
    "Monitoring Reader",
    "Monitoring Contributor"
]

# Check if role assignment is for a Redis resource
is_redis_role_assignment(assignment, redis_resource) if {
    scope := assignment.change.after.scope
    contains(scope, redis_resource.name)
}

is_redis_role_assignment(assignment, redis_resource) if {
    scope := assignment.change.after.scope
    contains(scope, "Microsoft.Cache/redis")
    contains(scope, redis_resource.name)
}

# Check if role is prohibited
is_prohibited_role(role_name) if {
    role_name in prohibited_roles
}

is_prohibited_role(role_name) if {
    contains(role_name, "Owner")
}

is_prohibited_role(role_name) if {
    contains(role_name, "Contributor")
    not contains(role_name, "Redis Cache Contributor")
    not contains(role_name, "Monitoring Contributor")
}

# Violation: Excessive RBAC permissions on Redis resource
violations[violation] {
    resource := redis_resources[_]
    assignment := role_assignments[_]
    is_redis_role_assignment(assignment, resource)
    
    role_definition_name := assignment.change.after.role_definition_name
    is_prohibited_role(role_definition_name)
    
    principal_id := assignment.change.after.principal_id
    
    violation := {
        "policy_id": policy_id,
        "policy_name": policy_name,
        "severity": severity,
        "category": category,
        "resource_type": resource.type,
        "resource_name": resource.name,
        "resource_address": resource.address,
        "violation": sprintf("Azure Managed Redis has excessive RBAC role assigned: '%s' for principal: %s", [role_definition_name, principal_id]),
        "rationale": "Least privilege principle requires using specific, limited roles instead of broad administrative roles to minimize security risk",
        "remediation": sprintf("For Redis instance '%s': Replace role '%s' with least-privilege alternatives such as 'Redis Cache Contributor' for management or 'Reader' for read-only access", [resource.name, role_definition_name]),
        "compliant": false,
        "blocking": true
    }
}

# Warning: Role assignment at subscription or resource group level affecting Redis
violations[violation] {
    assignment := role_assignments[_]
    scope := assignment.change.after.scope
    
    # Check if scope is subscription or resource group level
    contains(scope, "/subscriptions/")
    not contains(scope, "/providers/Microsoft.Cache/redis/")
    
    role_definition_name := assignment.change.after.role_definition_name
    is_prohibited_role(role_definition_name)
    
    # Check if any Redis resources exist in the plan
    count(redis_resources) > 0
    
    principal_id := assignment.change.after.principal_id
    
    violation := {
        "policy_id": policy_id,
        "policy_name": policy_name,
        "severity": "MEDIUM",
        "category": category,
        "resource_type": "azurerm_role_assignment",
        "resource_name": assignment.name,
        "resource_address": assignment.address,
        "violation": sprintf("Broad-scope RBAC role '%s' assigned at subscription/resource group level may grant excessive permissions to Redis resources", [role_definition_name]),
        "rationale": "Subscription or resource group level role assignments with high privileges violate least privilege when Redis resources are present",
        "remediation": sprintf("Limit role assignment scope to specific resources or use least-privilege roles. Consider using 'Redis Cache Contributor' scoped to individual Redis instances instead of '%s' at subscription/RG level", [role_definition_name]),
        "compliant": false,
        "blocking": false
    }
}

# Check for service principal or managed identity assignments
violations[violation] {
    resource := redis_resources[_]
    assignment := role_assignments[_]
    is_redis_role_assignment(assignment, resource)
    
    # Check if principal type is not specified or is ServicePrincipal
    principal_type := object.get(assignment.change.after, "principal_type", "ServicePrincipal")
    
    role_definition_name := assignment.change.after.role_definition_name
    
    # Even approved roles should be reviewed for service principals
    principal_type == "ServicePrincipal"
    role_definition_name in approved_redis_roles
    
    violation := {
        "policy_id": policy_id,
        "policy_name": policy_name,
        "severity": "LOW",
        "category": category,
        "resource_type": resource.type,
        "resource_name": resource.name,
        "resource_address": resource.address,
        "violation": sprintf("Service Principal has role '%s' on Redis resource - verify necessity and scope", [role_definition_name]),
        "rationale": "Service Principal access should be minimized and regularly reviewed to ensure continued necessity",
        "remediation": sprintf("For Redis instance '%s': Review and document the business justification for Service Principal access. Consider using Managed Identity where possible.", [resource.name]),
        "compliant": true,
        "blocking": false
    }
}

# Compliance decision
deny[msg] {
    blocking_violations := [v | v := violations[_]; v.blocking == true]
    count(blocking_violations) > 0
    msg := sprintf("BLOCK: %d RBAC assignment(s) violate least privilege policy for Redis resources", [count(blocking_violations)])
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
    "prohibited_roles": prohibited_roles,
    "approved_roles": approved_redis_roles
}
