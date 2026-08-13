#!/usr/bin/env python3
"""
ReviewAuditLog Generator

Generates structured ReviewAuditLog output that serves as a gating signal
for the CI/CD pipeline. Aggregates findings from all validators and scanners.
"""

import json
from datetime import datetime
from typing import Dict, List, Any, Optional
from pathlib import Path


class ReviewAuditLog:
    """Generates structured audit log for pipeline gating."""
    
    # Severity levels and their numeric weights for scoring
    SEVERITY_WEIGHTS = {
        "CRITICAL": 100,
        "HIGH": 50,
        "MEDIUM": 10,
        "LOW": 1,
        "INFO": 0
    }
    
    # Default thresholds for pipeline gating
    DEFAULT_THRESHOLDS = {
        "CRITICAL": 0,  # No critical issues allowed
        "HIGH": 5,      # Max 5 high severity issues
        "MEDIUM": 20,   # Max 20 medium severity issues
        "LOW": 50       # Max 50 low severity issues
    }
    
    def __init__(self, 
                 project_name: str,
                 scan_directory: str,
                 thresholds: Optional[Dict[str, int]] = None):
        """Initialize ReviewAuditLog generator.
        
        Args:
            project_name: Name of the project being scanned
            scan_directory: Directory that was scanned
            thresholds: Custom severity thresholds for gating (optional)
        """
        self.project_name = project_name
        self.scan_directory = scan_directory
        self.thresholds = thresholds or self.DEFAULT_THRESHOLDS
        self.findings = []
        self.metadata = {
            "scan_timestamp": datetime.utcnow().isoformat() + "Z",
            "project_name": project_name,
            "scan_directory": scan_directory,
            "tool_versions": {},
            "policy_versions": {}
        }
    
    def add_findings(self, findings: List[Dict[str, Any]], source: str):
        """Add findings from a validator or scanner.
        
        Args:
            findings: List of finding dictionaries
            source: Source tool/validator name
        """
        for finding in findings:
            finding["source"] = source
            self.findings.append(finding)
    
    def set_tool_version(self, tool_name: str, version: str):
        """Record tool version in metadata.
        
        Args:
            tool_name: Name of the tool
            version: Version string
        """
        self.metadata["tool_versions"][tool_name] = version
    
    def set_policy_version(self, policy_name: str, version: str):
        """Record policy version in metadata.
        
        Args:
            policy_name: Name of the policy
            version: Version string
        """
        self.metadata["policy_versions"][policy_name] = version
    
    def _calculate_severity_counts(self) -> Dict[str, int]:
        """Calculate count of findings by severity level."""
        counts = {severity: 0 for severity in self.SEVERITY_WEIGHTS.keys()}
        
        for finding in self.findings:
            severity = finding.get("severity", "INFO").upper()
            if severity in counts:
                counts[severity] += 1
            else:
                counts["INFO"] += 1
        
        return counts
    
    def _calculate_risk_score(self) -> int:
        """Calculate overall risk score based on findings."""
        score = 0
        
        for finding in self.findings:
            severity = finding.get("severity", "INFO").upper()
            weight = self.SEVERITY_WEIGHTS.get(severity, 0)
            score += weight
        
        return score
    
    def _determine_gate_status(self, severity_counts: Dict[str, int]) -> tuple[str, List[str]]:
        """Determine if the pipeline should pass or fail.
        
        Args:
            severity_counts: Count of findings by severity
            
        Returns:
            Tuple of (status, reasons) where status is PASS or FAIL
        """
        reasons = []
        
        for severity, threshold in self.thresholds.items():
            count = severity_counts.get(severity, 0)
            if count > threshold:
                reasons.append(
                    f"{severity} severity violations exceed threshold: "
                    f"{count} found, {threshold} allowed"
                )
        
        if reasons:
            return "FAIL", reasons
        else:
            return "PASS", ["All policy checks passed within acceptable thresholds"]
    
    def _group_findings_by_category(self) -> Dict[str, List[Dict[str, Any]]]:
        """Group findings by category/rule_id."""
        grouped = {}
        
        for finding in self.findings:
            rule_id = finding.get("rule_id", "UNKNOWN")
            if rule_id not in grouped:
                grouped[rule_id] = []
            grouped[rule_id].append(finding)
        
        return grouped
    
    def generate_summary(self) -> str:
        """Generate human-readable summary of findings."""
        severity_counts = self._calculate_severity_counts()
        total_findings = len(self.findings)
        
        summary_lines = [
            "=" * 80,
            f"Review Audit Summary for {self.project_name}",
            "=" * 80,
            f"Total Findings: {total_findings}",
            "",
            "Severity Breakdown:"
        ]
        
        for severity in ["CRITICAL", "HIGH", "MEDIUM", "LOW", "INFO"]:
            count = severity_counts.get(severity, 0)
            if count > 0:
                threshold = self.thresholds.get(severity, "N/A")
                summary_lines.append(f"  {severity}: {count} (threshold: {threshold})")
        
        summary_lines.extend(["", "Top Issues:"])
        
        # Show top 10 findings by severity
        sorted_findings = sorted(
            self.findings,
            key=lambda f: self.SEVERITY_WEIGHTS.get(f.get("severity", "INFO").upper(), 0),
            reverse=True
        )[:10]
        
        for i, finding in enumerate(sorted_findings, 1):
            summary_lines.append(
                f"  {i}. [{finding.get('severity', 'INFO')}] {finding.get('message', 'No message')}"
            )
        
        summary_lines.append("=" * 80)
        
        return "\n".join(summary_lines)
    
    def generate_log(self) -> Dict[str, Any]:
        """Generate complete ReviewAuditLog structure.
        
        Returns:
            Dictionary containing complete audit log
        """
        severity_counts = self._calculate_severity_counts()
        risk_score = self._calculate_risk_score()
        gate_status, gate_reasons = self._determine_gate_status(severity_counts)
        grouped_findings = self._group_findings_by_category()
        
        audit_log = {
            "metadata": self.metadata,
            "summary": {
                "total_findings": len(self.findings),
                "severity_counts": severity_counts,
                "risk_score": risk_score,
                "gate_status": gate_status,
                "gate_reasons": gate_reasons,
                "thresholds": self.thresholds
            },
            "findings": self.findings,
            "findings_by_category": {
                rule_id: {
                    "count": len(findings),
                    "severity": findings[0].get("severity", "INFO") if findings else "INFO",
                    "findings": findings
                }
                for rule_id, findings in grouped_findings.items()
            },
            "recommendations": self._generate_recommendations(grouped_findings)
        }
        
        return audit_log
    
    def _generate_recommendations(self, grouped_findings: Dict[str, List[Dict[str, Any]]]) -> List[str]:
        """Generate remediation recommendations based on findings."""
        recommendations = []
        
        # Prioritize by severity and frequency
        for rule_id, findings in sorted(
            grouped_findings.items(),
            key=lambda x: (self.SEVERITY_WEIGHTS.get(x[1][0].get("severity", "INFO").upper(), 0), len(x[1])),
            reverse=True
        )[:5]:  # Top 5 issues
            count = len(findings)
            severity = findings[0].get("severity", "INFO")
            remediation = findings[0].get("remediation", "No remediation guidance available")
            
            recommendations.append(
                f"[{severity}] {rule_id}: {count} occurrence(s) - {remediation}"
            )
        
        return recommendations
    
    def save_to_file(self, output_path: Path):
        """Save audit log to JSON file.
        
        Args:
            output_path: Path where to save the audit log
        """
        audit_log = self.generate_log()
        
        with open(output_path, 'w') as f:
            json.dump(audit_log, f, indent=2)
        
        print(f"ReviewAuditLog saved to: {output_path}")
        print(f"Gate Status: {audit_log['summary']['gate_status']}")
        
        return audit_log


if __name__ == "__main__":
    # Example usage
    log = ReviewAuditLog(
        project_name="example-terraform-project",
        scan_directory="/path/to/terraform"
    )
    
    # Add some example findings
    log.add_findings([
        {
            "severity": "HIGH",
            "rule_id": "BANK-001",
            "file": "main.tf",
            "line": 10,
            "message": "Missing required tags",
            "remediation": "Add CostCenter tag"
        }
    ], "tagging_validator")
    
    # Generate and print
    print(log.generate_summary())
    print(json.dumps(log.generate_log(), indent=2))
