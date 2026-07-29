from __future__ import annotations

import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "review-evidence.py"
spec = importlib.util.spec_from_file_location("review_evidence", SCRIPT)
module = importlib.util.module_from_spec(spec)
assert spec and spec.loader
sys.modules[spec.name] = module
spec.loader.exec_module(module)


class ReviewEvidenceTests(unittest.TestCase):
    def test_zero_findings_is_valid_report(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "safe.yaml").write_text("image: example/app:1.2.3\n", encoding="utf-8")
            report = module.collect(root, None, "HEAD")
            self.assertEqual(0, report["summary"]["findings"])
            self.assertEqual("1.0", report["schema_version"])
            self.assertEqual("sensitive-diff", report["skipped"][0]["id"])

    def test_deterministic_unsafe_patterns_are_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            workflow = root / ".github/workflows/unsafe.yml"
            workflow.parent.mkdir(parents=True)
            workflow.write_text("permissions: write-all\njobs: {}\n", encoding="utf-8")
            secret = root / "secret.yaml"
            secret.write_text("apiVersion: v1\nkind: Secret\nstringData:\n  token: test\n", encoding="utf-8")
            latest = root / "deployment.yaml"
            latest.write_text("image: example/app:latest\n", encoding="utf-8")
            report = module.collect(root, None, "HEAD")
            self.assertEqual(
                {"HS-GHA-001", "HS-IMG-001", "HS-SEC-001"},
                {finding["rule_id"] for finding in report["findings"]},
            )

    def test_sensitive_diff_requires_judgment(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            subprocess.run(["git", "config", "user.email", "test@example.com"], cwd=root, check=True)
            subprocess.run(["git", "config", "user.name", "Test"], cwd=root, check=True)
            values = root / "values.yaml"
            values.write_text("existingClaim: photos\n", encoding="utf-8")
            subprocess.run(["git", "add", "."], cwd=root, check=True)
            subprocess.run(["git", "commit", "-qm", "base"], cwd=root, check=True)
            base = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
            values.write_text("existingClaim: photo-storage\n", encoding="utf-8")
            subprocess.run(["git", "add", "."], cwd=root, check=True)
            subprocess.run(["git", "commit", "-qm", "change"], cwd=root, check=True)
            report = module.collect(root, base, "HEAD")
            finding = next(item for item in report["findings"] if item["rule_id"] == "HS-DIFF-001")
            self.assertTrue(finding["requires_judgment"])
            self.assertEqual("warning", finding["status"])
            self.assertEqual(["photos"], finding["evidence"]["old_values"])
            self.assertEqual(["photo-storage"], finding["evidence"]["new_values"])


if __name__ == "__main__":
    unittest.main()
