#!/usr/bin/env python3
"""
Review Agent - Static Code Analysis & Quality Assurance

Main orchestrator for the Review Agent that coordinates all validators and scanners
to audit Terraform/HCL configurations against the bank's Platform Engineering Standards.

ADLC Phase: Static Code Analysis (SCA) & Quality Assurance
"""

import sys
import json
import argparse
import subprocess
from pathlib import Path
from typing import Dict, List, Any, Optional

# Import validators
sys.path.insert(0, str(Path(__file__).parent))
from validators.tagging_validator import TaggingValidator
from validators.documentation_validator import DocumentationValidator
from utils.audit_log_generator import ReviewAuditLog


class ReviewAgent:
    """Main Review Agent orchestrator."""
    
    def __init__(self, 
                 terraform_dir: Path,
                 project_name: str,
                 output_dir: Optional[Path] = None,
                 config_dir: Optional[Path] = None,
                 dry_run: bool = False):
        """Initialize Review Agent.
        
        Args:
            terraform_dir: Directory containing Terraform files to review
            project_name: Name of the project being reviewed
            output_dir: Directory for output files (default: terraform_dir)
            config_dir: Directory containing configuration files
            dry_run: If True, only report issues without enforcing gate
        """
        self.terraform_dir = Path(terraform_dir)
        self.project_name = project_name
        self.output_dir = Path(output_dir) if output_dir else self.terraform_dir
        self.config_dir = Path(config_dir) if config_dir else Path(__file__).parent / "config"
        self.dry_run = dry_run
        
        # Initialize audit log
        self.audit_log = ReviewAuditLog(
            project_name=project_name,
            scan_directory=str(self.terraform_dir)
        )
        
        # Ensure output directory exists
        self.output_dir.mkdir(parents=True, exist_ok=True)
    
    def run_tflint(self) -> List[Dict[str, Any]]:
        """Run TFLint static analysis.
        
        Returns:
            List of findings from TFLint
        """
        print("\n[1/4] Running TFLint...")
        findings = []
        
        tflint_config = self.config_dir / "tflint.hcl"
        
        try:
            # Check if tflint is installed
            result = subprocess.run(
                ["tflint", "--version"],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0:
                version = result.stdout.strip()
                self.audit_log.set_tool_version("tflint", version)
                
                # Run tflint
                cmd = [
                    "tflint",
                    "--format=json",
                    "--force",
                ]
                
                if tflint_config.exists():
                    cmd.extend(["--config", str(tflint_config)])
                
                result = subprocess.run(
                    cmd,
                    cwd=str(self.terraform_dir),
                    capture_output=True,
                    text=True,
                    timeout=300
                )
                
                if result.stdout:
                    tflint_output = json.loads(result.stdout)
                    
                    # Parse TFLint issues
                    for issue in tflint_output.get("issues", []):
                        findings.append({
                            "severity": self._map_tflint_severity(issue.get("rule", {}).get("severity", "warning")),
                            "rule_id": issue.get("rule", {}).get("name", "TFLINT-UNKNOWN"),
                            "file": issue.get("range", {}).get("filename", "unknown"),
                            "line": issue.get("range", {}).get("start", {}).get("line", 0),
                            "message": issue.get("message", "No message"),
                            "remediation": f"See TFLint documentation for rule: {issue.get('rule', {}).get('name', 'unknown')}"
                        })
                    
                    print(f"  ✓ TFLint completed: {len(findings)} issues found")
            else:
                print("  ⚠ TFLint not installed, skipping...")
                findings.append({
                    "severity": "INFO",
                    "rule_id": "TFLINT-MISSING",
                    "file": "N/A",
                    "line": 0,
                    "message": "TFLint is not installed or not in PATH",
                    "remediation": "Install TFLint: https://github.com/terraform-linters/tflint"
                })
        
        except subprocess.TimeoutExpired:
            print("  ✗ TFLint timed out")
            findings.append({
                "severity": "ERROR",
                "rule_id": "TFLINT-TIMEOUT",
                "file": "N/A",
                "line": 0,
                "message": "TFLint execution timed out",
                "remediation": "Check TFLint configuration and Terraform code complexity"
            })
        
        except Exception as e:
            print(f"  ✗ TFLint failed: {str(e)}")
            findings.append({
                "severity": "INFO",
                "rule_id": "TFLINT-ERROR",
                "file": "N/A",
                "line": 0,
                "message": f"TFLint execution failed: {str(e)}",
                "remediation": "Ensure TFLint is properly installed and configured"
            })
        
        return findings
    
    def run_tfsec(self) -> List[Dict[str, Any]]:
        """Run TFSec security analysis.
        
        Returns:
            List of findings from TFSec
        """
        print("\n[2/4] Running TFSec...")
        findings = []
        
        try:
            # Check if tfsec is installed
            result = subprocess.run(
                ["tfsec", "--version"],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0:
                version = result.stdout.strip()
                self.audit_log.set_tool_version("tfsec", version)
                
                # Run tfsec
                result = subprocess.run(
                    [
                        "tfsec",
                        str(self.terraform_dir),
                        "--format=json",
                        "--soft-fail"
                    ],
                    capture_output=True,
                    text=True,
                    timeout=300
                )
                
                if result.stdout:
                    tfsec_output = json.loads(result.stdout)
                    
                    # Parse TFSec results
                    for issue in tfsec_output.get("results", []):
                        findings.append({
                            "severity": issue.get("severity", "MEDIUM").upper(),
                            "rule_id": issue.get("rule_id", "TFSEC-UNKNOWN"),
                            "file": issue.get("location", {}).get("filename", "unknown"),
                            "line": issue.get("location", {}).get("start_line", 0),
                            "message": issue.get("description", "No description"),
                            "remediation": issue.get("resolution", "See TFSec documentation")
                        })
                    
                    print(f"  ✓ TFSec completed: {len(findings)} issues found")
            else:
                print("  ⚠ TFSec not installed, skipping...")
                findings.append({
                    "severity": "INFO",
                    "rule_id": "TFSEC-MISSING",
                    "file": "N/A",
                    "line": 0,
                    "message": "TFSec is not installed or not in PATH",
                    "remediation": "Install TFSec: https://github.com/aquasecurity/tfsec"
                })
        
        except subprocess.TimeoutExpired:
            print("  ✗ TFSec timed out")
            findings.append({
                "severity": "ERROR",
                "rule_id": "TFSEC-TIMEOUT",
                "file": "N/A",
                "line": 0,
                "message": "TFSec execution timed out",
                "remediation": "Check Terraform code complexity"
            })
        
        except Exception as e:
            print(f"  ✗ TFSec failed: {str(e)}")
            findings.append({
                "severity": "INFO",
                "rule_id": "TFSEC-ERROR",
                "file": "N/A",
                "line": 0,
                "message": f"TFSec execution failed: {str(e)}",
                "remediation": "Ensure TFSec is properly installed"
            })
        
        return findings
    
    def run_tagging_validation(self) -> List[Dict[str, Any]]:
        """Run Cost-Center Metadata Policy validation.
        
        Returns:
            List of tagging violations
        """
        print("\n[3/4] Running Tagging Validation...")
        
        validator = TaggingValidator()
        findings = validator.validate_directory(self.terraform_dir)
        
        self.audit_log.set_policy_version("Cost-Center Metadata Policy", "1.0")
        print(f"  ✓ Tagging validation completed: {len(findings)} issues found")
        
        return findings
    
    def run_documentation_validation(self) -> List[Dict[str, Any]]:
        """Run documentation field validation.
        
        Returns:
            List of documentation violations
        """
        print("\n[4/4] Running Documentation Validation...")
        
        validator = DocumentationValidator()
        findings = validator.validate_directory(self.terraform_dir)
        
        self.audit_log.set_policy_version("Platform Engineering Standards", "1.0")
        print(f"  ✓ Documentation validation completed: {len(findings)} issues found")
        
        return findings
    
    def _map_tflint_severity(self, severity: str) -> str:
        """Map TFLint severity to standard severity levels."""
        mapping = {
            "error": "HIGH",
            "warning": "MEDIUM",
            "notice": "LOW"
        }
        return mapping.get(severity.lower(), "MEDIUM")
    
    def run_all_checks(self) -> Dict[str, Any]:
        """Run all validation checks and generate audit log.
        
        Returns:
            Complete audit log dictionary
        """
        print(f"\n{'='*80}")
        print(f"Review Agent - Static Code Analysis")
        print(f"Project: {self.project_name}")
        print(f"Directory: {self.terraform_dir}")
        print(f"Mode: {'DRY RUN (advisory only)' if self.dry_run else 'ENFORCEMENT'}")
        print(f"{'='*80}")
        
        # Run all validators and scanners
        tflint_findings = self.run_tflint()
        self.audit_log.add_findings(tflint_findings, "tflint")
        
        tfsec_findings = self.run_tfsec()
        self.audit_log.add_findings(tfsec_findings, "tfsec")
        
        tagging_findings = self.run_tagging_validation()
        self.audit_log.add_findings(tagging_findings, "tagging_validator")
        
        doc_findings = self.run_documentation_validation()
        self.audit_log.add_findings(doc_findings, "documentation_validator")
        
        # Generate audit log
        print(f"\n{'='*80}")
        print("Generating ReviewAuditLog...")
        print(f"{'='*80}")
        
        output_file = self.output_dir / "review_audit_log.json"
        audit_log_data = self.audit_log.save_to_file(output_file)
        
        # Print summary
        print("\n" + self.audit_log.generate_summary())
        
        # Determine exit code
        gate_status = audit_log_data["summary"]["gate_status"]
        
        if self.dry_run:
            print("\n[DRY RUN] Pipeline gate would be:", gate_status)
            return audit_log_data
        
        if gate_status == "FAIL":
            print("\n❌ PIPELINE GATE: FAILED")
            print("\nReasons:")
            for reason in audit_log_data["summary"]["gate_reasons"]:
                print(f"  • {reason}")
            print("\nReview the audit log and fix violations before proceeding.")
        else:
            print("\n✅ PIPELINE GATE: PASSED")
            print("\nAll policy checks passed. Safe to proceed.")
        
        return audit_log_data


def main():
    """Main entry point for Review Agent CLI."""
    parser = argparse.ArgumentParser(
        description="Review Agent - Static Code Analysis for Terraform/HCL",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Run review on current directory
  %(prog)s --project my-infrastructure .
  
  # Run in dry-run mode (advisory only)
  %(prog)s --project my-infrastructure --dry-run /path/to/terraform
  
  # Specify custom output directory
  %(prog)s --project my-infrastructure --output ./reports /path/to/terraform
        """
    )
    
    parser.add_argument(
        "terraform_dir",
        help="Directory containing Terraform files to review"
    )
    
    parser.add_argument(
        "--project",
        required=True,
        help="Project name for audit log"
    )
    
    parser.add_argument(
        "--output",
        help="Output directory for audit log (default: same as terraform_dir)"
    )
    
    parser.add_argument(
        "--config",
        help="Directory containing configuration files"
    )
    
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Run in advisory mode without enforcing gate"
    )
    
    args = parser.parse_args()
    
    # Create and run review agent
    agent = ReviewAgent(
        terraform_dir=args.terraform_dir,
        project_name=args.project,
        output_dir=args.output,
        config_dir=args.config,
        dry_run=args.dry_run
    )
    
    audit_log = agent.run_all_checks()
    
    # Exit with appropriate code
    if not args.dry_run and audit_log["summary"]["gate_status"] == "FAIL":
        sys.exit(1)
    else:
        sys.exit(0)


if __name__ == "__main__":
    main()
