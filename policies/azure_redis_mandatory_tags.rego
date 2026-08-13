package azure.redis.mandatory_tags

import future.keywords.if
import future.keywords.in

# Policy Metadata
policy_id := "AZURE-REDIS-TAG-001"
policy_name := "Azure Managed Redis Mandatory Banking Tags Enforcement"
policy_version := "1.0.0"
severity := "HIGH"
category := "Governance & Compliance"

# Hard-Mandate: No Azure Managed Redis resource without mandatory banking tags
# such as Cost Center, Business Unit, Environment, Owner, Application, and Data Classification.

# Define mandatory tags required for all Redis resources
mandatory_tags := [
    "CostCenter",
    "BusinessUnit",
    "Environment",
    "Owner",
    "Application",
    "DataClassification"
]

# Extract all Azure Redis Cache resources from Terraform plan
redis_resources[resource] {
    resource := input.resource_changes[_]
    resource.type == "azurerm_redis_cache"
    resource.change.actions[_] != "delete"
}

# Get tags from resource
get_tags(resource) := tags {
    tags := object.get(resource.change.after, "tags", {})
}

# Check if all mandatory tags are present and non-empty
missing_tags(resource) := missing {
    tags := get_tags(resource)
    missing := [tag | 
        tag := mandatory_tags[_]
        not tags[tag]
    ]
}

empty_tags(resource) := empty {
    tags := get_tags(resource)
    empty := [tag | 
        tag := mandatory_tags[_]
        value := tags[tag]
        value == ""
    ]
}

# Violation: Missing mandatory tags
violations[violation] {
    resource := redis_resources[_]
    missing := missing_tags(resource)
    count(missing) > 0
    
    violation := {
        "policy_id": policy_id,
        "policy_name": policy_name,
        "severity": severity,
        "category": category,
        "resource_type": resource.type,
        "resource_name": resource.name,
        "resource_address": resource.address,
        "violation": sprintf("Azure Managed Redis instance is missing mandatory tags: %v", [missing]),
        "rationale": "Mandatory tags are required for cost allocation, governance, compliance tracking, and operational management",
        "remediation": sprintf("For Redis instance '%s': Add the following mandatory tags to the 'tags' block: %v", [resource.name, missing]),
        "compliant": false,
        "blocking": true
    }
}

# Violation: Empty mandatory tags
violations[violation] {
    resource := redis_resources[_]
    empty := empty_tags(resource)
    count(empty) > 0
    
    violation := {
        "policy_id": policy_id,
        "policy_name": policy_name,
        "severity": severity,
        "category": category,
        "resource_type": resource.type,
        "resource_name": resource.name,
        "resource_address": resource.address,
        "violation": sprintf("Azure Managed Redis instance has empty values for mandatory tags: %v", [empty]),
        "rationale": "Mandatory tags must have non-empty values for effective governance and compliance",
        "remediation": sprintf("For Redis instance '%s': Provide non-empty values for the following tags: %v", [resource.name, empty]),
        "compliant": false,
        "blocking": true
    }
}

# Validate specific tag values
violations[violation] {
    resource := redis_resources[_]
    tags := get_tags(resource)
    
    # Environment tag must be one of the approved values
    environment := object.get(tags, "Environment", "")
    environment != ""
    not environment in ["Development", "Dev", "Testing", "Test", "QA", "Staging", "Stage", "Production", "Prod", "Sandbox"]
    
    violation := {
        "policy_id": policy_id,
        "policy_name": policy_name,
        "severity": "MEDIUM",
        "category": category,
        "resource_type": resource.type,
        "resource_name": resource.name,
        "resource_address": resource.address,
        "violation": sprintf("Azure Managed Redis instance has invalid Environment tag value: '%s'", [environment]),
        "rationale": "Environment tag must use standardized values for consistent governance",
        "remediation": sprintf("For Redis instance '%s': Set Environment tag to one of: Development, Dev, Testing, Test, QA, Staging, Stage, Production, Prod, Sandbox", [resource.name]),
        "compliant": false,
        "blocking": false
    }
}

violations[violation] {
    resource := redis_resources[_]
    tags := get_tags(resource)
    
    # DataClassification tag must be one of the approved values
    data_classification := object.get(tags, "DataClassification", "")
    data_classification != ""
    not data_classification in ["Public", "Internal", "Confidential", "Restricted", "HighlyConfidential", "PII", "PHI"]
    
    violation := {
        "policy_id": policy_id,
        "policy_name": policy_name,
        "severity": "MEDIUM",
        "category": category,
        "resource_type": resource.type,
        "resource_name": resource.name,
        "resource_address": resource.address,
        "violation": sprintf("Azure Managed Redis instance has invalid DataClassification tag value: '%s'", [data_classification]),
        "rationale": "DataClassification tag must use standardized values to enforce appropriate security controls",
        "remediation": sprintf("For Redis instance '%s': Set DataClassification tag to one of: Public, Internal, Confidential, Restricted, HighlyConfidential, PII, PHI", [resource.name]),
        "compliant": false,
        "blocking": false
    }
}

# Compliance decision
deny[msg] {
    blocking_violations := [v | v := violations[_]; v.blocking == true]
    count(blocking_violations) > 0
    msg := sprintf("BLOCK: %d Azure Redis instance(s) violate mandatory tags policy", [count(blocking_violations)])
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
    "mandatory_tags": mandatory_tags
}
