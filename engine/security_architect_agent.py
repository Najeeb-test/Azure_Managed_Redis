#!/usr/bin/env python3
"""
Security Architect Agent - Azure Redis Compliance Guardrail Enforcement

Executes high-fidelity security auditing using Open Policy Agent (OPA).
Evaluates Terraform Plan JSON against Rego-based banking security hard-mandates.
Produces ComplianceCertificate for production release approval.
"""

import json
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Any, Optional
from datetime import datetime
import yaml


class SecurityArchitectAgent:
    """Main agent for compliance guardrail enforcement."""
    
    def __init__(self, policy_dir: str = "../policies"):
        self.policy_dir = Path(policy_dir)
        self.opa_binary = "opa"  # Assumes OPA is installed and in PATH
        self.policy_set_version = "1.0.0"
        self.agent_version = "1.0.0"
        
    def validate_opa_installation(self) -> bool:
        """Check if OPA is installed and accessible."""
        try:
            result = subprocess.run(
                [self.opa_binary, "version"],
                capture_output=True,
                text=True,
                timeout=5
            )
            return result.returncode == 0
        except (subprocess.SubprocessError, FileNotFoundError):
            return False
    
    def load_terraform_plan(self, plan_path: str) -> Dict[str, Any]:
        """Load and parse Terraform plan JSON."""
        plan_file = Path(plan_path)
        if not plan_file.exists():
            raise FileNotFoundError(f"Terraform plan not found: {plan_path}")
        
        with open(plan_file, 'r') as f:
            plan_data = json.load(f)
        
        # Validate plan structure
        if "resource_changes" not in plan_data:
            raise ValueError("Invalid Terraform plan: missing 'resource_changes' key")
        
        return plan_data
    
    def get_policy_files(self) -> List[Path]:
        """Get all Rego policy files from policy directory."""
        if not self.policy_dir.exists():
            raise FileNotFoundError(f"Policy directory not found: {self.policy_dir}")
        
        policy_files = list(self.policy_dir.glob("*.rego"))
        if not policy_files:
            raise ValueError(f"No Rego policy files found in {self.policy_dir}")
        
        return policy_files
    
    def evaluate_policy(self, plan_data: Dict[str, Any], policy_file: Path) -> Dict[str, Any]:
        """Evaluate a single policy against the Terraform plan using OPA."""
        # Create temporary input file
        import tempfile
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as tmp:
            json.dump(plan_data, tmp)
            input_file = tmp.name
        
        try:
            # Run OPA evaluation
            # Query both summary and deny rules
            cmd = [
                self.opa_binary,
                "eval",
                "--data", str(policy_file),
                "--input", input_file,
                "--format", "json",
                "data"
            ]
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode != 0:
                raise RuntimeError(f"OPA evaluation failed: {result.stderr}")
            
            output = json.loads(result.stdout)
            
            # Extract results from OPA output
            if "result" in output and len(output["result"]) > 0:
                return output["result"][0]["expressions"][0]["value"]
            
            return {}
            
        finally:
            # Clean up temporary file
            Path(input_file).unlink(missing_ok=True)
    
    def aggregate_policy_results(self, policy_results: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Aggregate results from all policy evaluations."""
        all_violations = []
        all_denials = []
        policy_summaries = []
        
        for policy_result in policy_results:
            # Extract package-specific results
            for package_name, package_data in policy_result.items():
                if not isinstance(package_data, dict):
                    continue
                
                # Extract summary
                if "summary" in package_data:
                    summary = package_data["summary"]
                    policy_summaries.append(summary)
                    
                    # Extract violations from summary
                    if "violations" in summary and summary["violations"]:
                        all_violations.extend(summary["violations"])
                
                # Extract deny messages
                if "deny" in package_data and package_data["deny"]:
                    all_denials.extend(package_data["deny"])
        
        return {
            "violations": all_violations,
            "denials": all_denials,
            "policy_summaries": policy_summaries
        }
    
    def determine_compliance_decision(self, aggregated_results: Dict[str, Any]) -> str:
        """Determine overall compliance decision: PASS, FAIL, or BLOCK."""
        violations = aggregated_results.get("violations", [])
        
        if not violations:
            return "PASS"
        
        # Check for blocking violations
        blocking_violations = [v for v in violations if v.get("blocking", False)]
        
        if blocking_violations:
            return "BLOCK"
        
        return "FAIL"
    
    def generate_compliance_certificate(
        self,
        plan_path: str,
        aggregated_results: Dict[str, Any],
        compliance_decision: str,
        environment: Optional[str] = None
    ) -> Dict[str, Any]:
        """Generate structured ComplianceCertificate."""
        violations = aggregated_results.get("violations", [])
        policy_summaries = aggregated_results.get("policy_summaries", [])
        
        # Group violations by severity
        violations_by_severity = {
            "CRITICAL": [],
            "HIGH": [],
            "MEDIUM": [],
            "LOW": []
        }
        
        for violation in violations:
            severity = violation.get("severity", "MEDIUM")
            violations_by_severity[severity].append(violation)
        
        # Extract unique policy IDs and versions
        policies_evaluated = []
        for summary in policy_summaries:
            policies_evaluated.append({
                "policy_id": summary.get("policy_id"),
                "policy_name": summary.get("policy_name"),
                "policy_version": summary.get("policy_version"),
                "compliant": summary.get("compliant", False),
                "total_violations": summary.get("total_violations", 0)
            })
        
        certificate = {
            "compliance_certificate": {
                "version": "1.0",
                "generated_at": datetime.utcnow().isoformat() + "Z",
                "agent_version": self.agent_version,
                "policy_set_version": self.policy_set_version,
                "terraform_plan": str(plan_path),
                "environment": environment or "unknown",
                "compliance_decision": compliance_decision,
                "summary": {
                    "total_violations": len(violations),
                    "blocking_violations": len([v for v in violations if v.get("blocking", False)]),
                    "critical_violations": len(violations_by_severity["CRITICAL"]),
                    "high_violations": len(violations_by_severity["HIGH"]),
                    "medium_violations": len(violations_by_severity["MEDIUM"]),
                    "low_violations": len(violations_by_severity["LOW"]),
                    "policies_evaluated": len(policies_evaluated),
                    "compliant_policies": len([p for p in policies_evaluated if p["compliant"]])
                },
                "policies_evaluated": policies_evaluated,
                "violations": violations,
                "violations_by_severity": violations_by_severity,
                "approval_status": {
                    "production_release_approved": compliance_decision == "PASS",
                    "requires_remediation": compliance_decision in ["FAIL", "BLOCK"],
                    "blocking_issues": compliance_decision == "BLOCK"
                }
            }
        }
        
        return certificate
    
    def save_certificate(self, certificate: Dict[str, Any], output_path: str, format: str = "json"):
        """Save ComplianceCertificate to file."""
        output_file = Path(output_path)
        
        with open(output_file, 'w') as f:
            if format.lower() == "yaml":
                yaml.dump(certificate, f, default_flow_style=False, sort_keys=False)
            else:
                json.dump(certificate, f, indent=2)
        
        print(f"ComplianceCertificate saved to: {output_file}")
    
    def generate_remediation_report(self, violations: List[Dict[str, Any]]) -> str:
        """Generate human-readable remediation guidance."""
        if not violations:
            return "✅ No violations found. All policies are compliant."
        
        report_lines = []
        report_lines.append("\n" + "="*80)
        report_lines.append("REMEDIATION REPORT")
        report_lines.append("="*80)
        
        # Group by resource
        violations_by_resource = {}
        for violation in violations:
            resource_name = violation.get("resource_name", "unknown")
            if resource_name not in violations_by_resource:
                violations_by_resource[resource_name] = []
            violations_by_resource[resource_name].append(violation)
        
        for resource_name, resource_violations in violations_by_resource.items():
            report_lines.append(f"\n📦 Resource: {resource_name}")
            report_lines.append("-" * 80)
            
            for i, violation in enumerate(resource_violations, 1):
                severity = violation.get("severity", "UNKNOWN")
                policy_id = violation.get("policy_id", "N/A")
                violation_msg = violation.get("violation", "No description")
                rationale = violation.get("rationale", "No rationale provided")
                remediation = violation.get("remediation", "No remediation guidance")
                blocking = violation.get("blocking", False)
                
                severity_emoji = {
                    "CRITICAL": "🔴",
                    "HIGH": "🟠",
                    "MEDIUM": "🟡",
                    "LOW": "🟢"
                }.get(severity, "⚪")
                
                blocking_indicator = " [BLOCKING]" if blocking else ""
                
                report_lines.append(f"\n  {severity_emoji} Violation #{i}: {severity}{blocking_indicator}")
                report_lines.append(f"  Policy ID: {policy_id}")
                report_lines.append(f"  Issue: {violation_msg}")
                report_lines.append(f"  Rationale: {rationale}")
                report_lines.append(f"  Remediation: {remediation}")
        
        report_lines.append("\n" + "="*80)
        
        return "\n".join(report_lines)
    
    def run_compliance_check(
        self,
        plan_path: str,
        output_path: str = "compliance_certificate.json",
        output_format: str = "json",
        environment: Optional[str] = None,
        verbose: bool = True
    ) -> Dict[str, Any]:
        """Main execution method for compliance checking."""
        
        if verbose:
            print("🔒 Security Architect Agent - Azure Redis Compliance Check")
            print(f"   Version: {self.agent_version}")
            print(f"   Policy Set Version: {self.policy_set_version}")
            print()
        
        # Validate OPA installation
        if not self.validate_opa_installation():
            raise RuntimeError("OPA (Open Policy Agent) is not installed or not in PATH")
        
        if verbose:
            print("✅ OPA installation validated")
        
        # Load Terraform plan
        if verbose:
            print(f"📄 Loading Terraform plan: {plan_path}")
        plan_data = self.load_terraform_plan(plan_path)
        
        if verbose:
            resource_count = len(plan_data.get("resource_changes", []))
            print(f"   Found {resource_count} resource changes")
        
        # Get policy files
        policy_files = self.get_policy_files()
        if verbose:
            print(f"\n📋 Evaluating {len(policy_files)} policies:")
        
        # Evaluate each policy
        policy_results = []
        for policy_file in policy_files:
            if verbose:
                print(f"   - {policy_file.name}")
            
            result = self.evaluate_policy(plan_data, policy_file)
            policy_results.append(result)
        
        # Aggregate results
        if verbose:
            print("\n🔍 Aggregating policy results...")
        aggregated_results = self.aggregate_policy_results(policy_results)
        
        # Determine compliance decision
        compliance_decision = self.determine_compliance_decision(aggregated_results)
        
        if verbose:
            print(f"\n📊 Compliance Decision: {compliance_decision}")
            violations = aggregated_results.get("violations", [])
            print(f"   Total Violations: {len(violations)}")
            blocking = len([v for v in violations if v.get("blocking", False)])
            print(f"   Blocking Violations: {blocking}")
        
        # Generate certificate
        certificate = self.generate_compliance_certificate(
            plan_path,
            aggregated_results,
            compliance_decision,
            environment
        )
        
        # Save certificate
        self.save_certificate(certificate, output_path, output_format)
        
        # Generate and display remediation report
        if verbose and aggregated_results.get("violations"):
            remediation_report = self.generate_remediation_report(
                aggregated_results["violations"]
            )
            print(remediation_report)
        
        return certificate


def main():
    """CLI entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Security Architect Agent - Azure Redis Compliance Guardrail Enforcement"
    )
    parser.add_argument(
        "plan_path",
        help="Path to Terraform plan JSON file"
    )
    parser.add_argument(
        "--output", "-o",
        default="compliance_certificate.json",
        help="Output path for ComplianceCertificate (default: compliance_certificate.json)"
    )
    parser.add_argument(
        "--format", "-f",
        choices=["json", "yaml"],
        default="json",
        help="Output format (default: json)"
    )
    parser.add_argument(
        "--environment", "-e",
        help="Environment name (e.g., production, staging)"
    )
    parser.add_argument(
        "--policy-dir", "-p",
        default="../policies",
        help="Path to policy directory (default: ../policies)"
    )
    parser.add_argument(
        "--quiet", "-q",
        action="store_true",
        help="Suppress verbose output"
    )
    
    args = parser.parse_args()
    
    try:
        agent = SecurityArchitectAgent(policy_dir=args.policy_dir)
        certificate = agent.run_compliance_check(
            plan_path=args.plan_path,
            output_path=args.output,
            output_format=args.format,
            environment=args.environment,
            verbose=not args.quiet
        )
        
        # Exit with appropriate code
        decision = certificate["compliance_certificate"]["compliance_decision"]
        if decision == "PASS":
            sys.exit(0)
        elif decision == "FAIL":
            sys.exit(1)
        else:  # BLOCK
            sys.exit(2)
            
    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        sys.exit(3)


if __name__ == "__main__":
    main()
