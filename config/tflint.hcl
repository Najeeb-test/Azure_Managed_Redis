# TFLint Configuration for Bank's Platform Engineering Standards
# This configuration enforces naming conventions, code quality, and best practices

config {
  module = true
  force = false
}

# Enable AWS plugin for AWS-specific rules
plugin "aws" {
  enabled = true
  version = "0.29.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Enable Terraform plugin for general Terraform best practices
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Naming Convention Rules
rule "terraform_naming_convention" {
  enabled = true
  
  # Resource naming: lowercase, underscores, descriptive
  resource = "snake_case"
  
  # Variable naming: lowercase, underscores
  variable = "snake_case"
  
  # Output naming: lowercase, underscores
  output = "snake_case"
  
  # Module naming: lowercase, hyphens
  module = "snake_case"
}

# Enforce description on variables
rule "terraform_documented_variables" {
  enabled = true
}

# Enforce description on outputs
rule "terraform_documented_outputs" {
  enabled = true
}

# Detect deprecated syntax
rule "terraform_deprecated_index" {
  enabled = true
}

# Enforce standard module structure
rule "terraform_standard_module_structure" {
  enabled = true
}

# Require variable type declarations
rule "terraform_typed_variables" {
  enabled = true
}

# Detect unused declarations
rule "terraform_unused_declarations" {
  enabled = true
}

# Enforce workspace usage patterns
rule "terraform_workspace_remote" {
  enabled = true
}

# AWS-specific rules
rule "aws_resource_missing_tags" {
  enabled = true
  tags = [
    "CostCenter",
    "BusinessUnit",
    "Environment",
    "Owner",
    "Project",
    "ManagedBy"
  ]
}

# Detect invalid instance types
rule "aws_instance_invalid_type" {
  enabled = true
}

# Enforce encryption
rule "aws_s3_bucket_encryption" {
  enabled = true
}

rule "aws_db_instance_encryption" {
  enabled = true
}

# Prevent public exposure
rule "aws_s3_bucket_public_access_block" {
  enabled = true
}

rule "aws_security_group_invalid_ingress" {
  enabled = true
}
