#!/usr/bin/env python3
"""
Documentation Field Validator

Validates that all Terraform variables and outputs have proper description fields
according to the bank's Platform Engineering Standards.

Requirements:
- All variables must have non-empty description fields
- All outputs must have non-empty description fields
- Descriptions must be meaningful (not just placeholder text)
- Descriptions should be at least 10 characters long
"""

import re
import json
from typing import Dict, List, Any
from pathlib import Path


class DocumentationValidator:
    """Validates Terraform documentation compliance."""
    
    # Minimum description length
    MIN_DESCRIPTION_LENGTH = 10
    
    # Placeholder patterns that are not acceptable
    PLACEHOLDER_PATTERNS = [
        r'^\s*todo\s*$',
        r'^\s*tbd\s*$',
        r'^\s*fixme\s*$',
        r'^\s*description\s*$',
        r'^\s*\.\.\.*\s*$',
        r'^\s*-+\s*$',
    ]
    
    def __init__(self):
        self.violations = []
    
    def validate_file(self, filepath: Path) -> List[Dict[str, Any]]:
        """Validate a single Terraform file for documentation compliance.
        
        Args:
            filepath: Path to the Terraform file
            
        Returns:
            List of violation dictionaries
        """
        self.violations = []
        
        try:
            content = filepath.read_text()
            self._validate_variables(content, str(filepath))
            self._validate_outputs(content, str(filepath))
        except Exception as e:
            self.violations.append({
                "severity": "ERROR",
                "rule_id": "BANK-003",
                "file": str(filepath),
                "line": 0,
                "message": f"Failed to parse file: {str(e)}",
                "remediation": "Ensure the file is valid HCL syntax"
            })
        
        return self.violations
    
    def _validate_variables(self, content: str, filepath: str):
        """Validate variable blocks for description fields."""
        # Pattern: variable "name" { ... }
        variable_pattern = r'variable\s+"([^"]+)"\s*\{([^}]*(?:\{[^}]*\}[^}]*)*)\}'
        
        for match in re.finditer(variable_pattern, content, re.MULTILINE | re.DOTALL):
            var_name = match.group(1)
            var_body = match.group(2)
            line_num = content[:match.start()].count('\n') + 1
            
            # Check for description field
            desc_match = re.search(r'description\s*=\s*"([^"]*(?:\\.[^"]*)*)"|description\s*=\s*<<-?\s*(\w+)\s*\n(.*?)\n\s*\2', var_body, re.DOTALL)
            
            if not desc_match:
                self.violations.append({
                    "severity": "MEDIUM",
                    "rule_id": "BANK-003",
                    "file": filepath,
                    "line": line_num,
                    "element": f"variable.{var_name}",
                    "message": f"Variable '{var_name}' is missing description field",
                    "remediation": f"Add description field to variable '{var_name}' explaining its purpose and expected values"
                })
                continue
            
            # Extract description text
            description = desc_match.group(1) if desc_match.group(1) is not None else desc_match.group(3)
            
            # Validate description quality
            self._validate_description_quality(description, f"variable.{var_name}", filepath, line_num)
    
    def _validate_outputs(self, content: str, filepath: str):
        """Validate output blocks for description fields."""
        # Pattern: output "name" { ... }
        output_pattern = r'output\s+"([^"]+)"\s*\{([^}]*(?:\{[^}]*\}[^}]*)*)\}'
        
        for match in re.finditer(output_pattern, content, re.MULTILINE | re.DOTALL):
            output_name = match.group(1)
            output_body = match.group(2)
            line_num = content[:match.start()].count('\n') + 1
            
            # Check for description field
            desc_match = re.search(r'description\s*=\s*"([^"]*(?:\\.[^"]*)*)"|description\s*=\s*<<-?\s*(\w+)\s*\n(.*?)\n\s*\2', output_body, re.DOTALL)
            
            if not desc_match:
                self.violations.append({
                    "severity": "MEDIUM",
                    "rule_id": "BANK-003",
                    "file": filepath,
                    "line": line_num,
                    "element": f"output.{output_name}",
                    "message": f"Output '{output_name}' is missing description field",
                    "remediation": f"Add description field to output '{output_name}' explaining what value it exposes and its purpose"
                })
                continue
            
            # Extract description text
            description = desc_match.group(1) if desc_match.group(1) is not None else desc_match.group(3)
            
            # Validate description quality
            self._validate_description_quality(description, f"output.{output_name}", filepath, line_num)
    
    def _validate_description_quality(self, description: str, element: str, filepath: str, line_num: int):
        """Validate that description is meaningful and not a placeholder."""
        # Check if empty or too short
        if not description or len(description.strip()) < self.MIN_DESCRIPTION_LENGTH:
            self.violations.append({
                "severity": "MEDIUM",
                "rule_id": "BANK-003",
                "file": filepath,
                "line": line_num,
                "element": element,
                "message": f"{element} has description that is too short or empty (minimum {self.MIN_DESCRIPTION_LENGTH} characters)",
                "remediation": f"Provide a meaningful description for {element} that explains its purpose, expected values, and usage"
            })
            return
        
        # Check for placeholder patterns
        desc_lower = description.strip().lower()
        for pattern in self.PLACEHOLDER_PATTERNS:
            if re.match(pattern, desc_lower, re.IGNORECASE):
                self.violations.append({
                    "severity": "MEDIUM",
                    "rule_id": "BANK-003",
                    "file": filepath,
                    "line": line_num,
                    "element": element,
                    "message": f"{element} has placeholder description: '{description}'",
                    "remediation": f"Replace placeholder with meaningful description for {element}"
                })
                return
    
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
        print("Usage: documentation_validator.py <terraform_directory>")
        sys.exit(1)
    
    validator = DocumentationValidator()
    violations = validator.validate_directory(Path(sys.argv[1]))
    
    print(json.dumps(violations, indent=2))
    
    if violations:
        sys.exit(1)
