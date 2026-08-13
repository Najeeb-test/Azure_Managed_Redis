#!/usr/bin/env python3
"""
Cost-Center Metadata Policy Validator

Validates that all Terraform resources include required tags according to
the bank's Cost-Center Metadata Policy.

Required Tags:
- CostCenter: Cost center code for billing
- BusinessUnit: Business unit identifier
- Environment: Environment name (dev, staging, prod)
- Owner: Team or individual responsible
- Project: Project identifier
- ManagedBy: Management tool (e.g., Terraform)
"""

import re
import json
from typing import Dict, List, Any, Set
from pathlib import Path


class TaggingValidator:
    """Validates Terraform resource tagging compliance."""
    
    # Required tags per bank's Cost-Center Metadata Policy
    REQUIRED_TAGS = [
        "CostCenter",
        "BusinessUnit",
        "Environment",
        "Owner",
        "Project",
        "ManagedBy"
    ]
    
    # AWS resources that must be tagged
    TAGGABLE_RESOURCES = [
        "aws_instance",
        "aws_s3_bucket",
        "aws_db_instance",
        "aws_rds_cluster",
        "aws_ecs_cluster",
        "aws_ecs_service",
        "aws_ecs_task_definition",
        "aws_lambda_function",
        "aws_vpc",
        "aws_subnet",
        "aws_security_group",
        "aws_ebs_volume",
        "aws_elb",
        "aws_lb",
        "aws_autoscaling_group",
        "aws_cloudwatch_log_group",
        "aws_dynamodb_table",
        "aws_elasticache_cluster",
        "aws_elasticsearch_domain",
        "aws_kinesis_stream",
        "aws_kms_key",
        "aws_sns_topic",
        "aws_sqs_queue",
    ]
    
    def __init__(self):
        self.violations = []
        
    def validate_file(self, filepath: Path) -> List[Dict[str, Any]]:
        """Validate a single Terraform file for tagging compliance.
        
        Args:
            filepath: Path to the Terraform file
            
        Returns:
            List of violation dictionaries
        """
        self.violations = []
        
        try:
            content = filepath.read_text()
            self._parse_and_validate(content, str(filepath))
        except Exception as e:
            self.violations.append({
                "severity": "ERROR",
                "rule_id": "BANK-001",
                "file": str(filepath),
                "line": 0,
                "message": f"Failed to parse file: {str(e)}",
                "remediation": "Ensure the file is valid HCL syntax"
            })
            
        return self.violations
    
    def _parse_and_validate(self, content: str, filepath: str):
        """Parse HCL content and validate resource tags."""
        # Simple regex-based parsing for resource blocks
        # Format: resource "type" "name" { ... }
        resource_pattern = r'resource\s+"([^"]+)"\s+"([^"]+)"\s*\{([^}]*(?:\{[^}]*\}[^}]*)*)\}'
        
        for match in re.finditer(resource_pattern, content, re.MULTILINE | re.DOTALL):
            resource_type = match.group(1)
            resource_name = match.group(2)
            resource_body = match.group(3)
            
            # Only validate taggable resources
            if resource_type not in self.TAGGABLE_RESOURCES:
                continue
            
            # Find line number
            line_num = content[:match.start()].count('\n') + 1
            
            # Check for tags or tags_all block
            tags_match = re.search(r'tags\s*=\s*\{([^}]*)\}', resource_body)
            
            if not tags_match:
                self.violations.append({
                    "severity": "HIGH",
                    "rule_id": "BANK-001",
                    "file": filepath,
                    "line": line_num,
                    "resource": f"{resource_type}.{resource_name}",
                    "message": f"Resource '{resource_type}.{resource_name}' is missing tags block",
                    "remediation": f"Add tags block with required tags: {', '.join(self.REQUIRED_TAGS)}"
                })
                continue
            
            # Extract defined tags
            tags_content = tags_match.group(1)
            defined_tags = self._extract_tag_keys(tags_content)
            
            # Check for missing required tags
            missing_tags = set(self.REQUIRED_TAGS) - defined_tags
            
            if missing_tags:
                self.violations.append({
                    "severity": "HIGH",
                    "rule_id": "BANK-001",
                    "file": filepath,
                    "line": line_num,
                    "resource": f"{resource_type}.{resource_name}",
                    "message": f"Resource '{resource_type}.{resource_name}' is missing required tags: {', '.join(sorted(missing_tags))}",
                    "remediation": f"Add missing tags to comply with Cost-Center Metadata Policy: {', '.join(sorted(missing_tags))}"
                })
    
    def _extract_tag_keys(self, tags_content: str) -> Set[str]:
        """Extract tag keys from tags block content."""
        tag_keys = set()
        
        # Match tag definitions: key = "value" or key = var.something
        tag_pattern = r'([A-Za-z][A-Za-z0-9_]*)\s*='
        
        for match in re.finditer(tag_pattern, tags_content):
            tag_keys.add(match.group(1))
        
        return tag_keys
    
    def validate_directory(self, directory: Path) -> List[Dict[str, Any]]:
        """Validate all Terraform files in a directory.
        
        Args:
            directory: Path to directory containing Terraform files
            
        Returns:
            List of all violations found
        """
        all_violations = []
        
        for tf_file in directory.rglob("*.tf"):
            violations = self.validate_file(tf_file)
            all_violations.extend(violations)
        
        return all_violations


if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: tagging_validator.py <terraform_directory>")
        sys.exit(1)
    
    validator = TaggingValidator()
    violations = validator.validate_directory(Path(sys.argv[1]))
    
    print(json.dumps(violations, indent=2))
    
    if violations:
        sys.exit(1)
