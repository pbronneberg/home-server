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


def commit(root: Path, message: str) -> str:
    subprocess.run(["git", "add", "."], cwd=root, check=True)
    subprocess.run(["git", "commit", "-qm", message], cwd=root, check=True)
    return subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()


class ReviewEvidenceTests(unittest.TestCase):
    def test_zero_findings_is_valid_report(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "safe.yaml").write_text("image: example/app:1.2.3\n", encoding="utf-8")
            report = module.collect(root, None, "HEAD")
            self.assertEqual(0, report["summary"]["findings"])
            self.assertEqual("1.0", report["schema_version"])
            self.assertEqual("all-fallback", report["scope"])

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
            base = commit(root, "base")
            values.write_text("existingClaim: photo-storage\n", encoding="utf-8")
            commit(root, "change")
            report = module.collect(root, base, "HEAD")
            finding = next(item for item in report["findings"] if item["rule_id"] == "HS-DIFF-001")
            self.assertTrue(finding["requires_judgment"])
            self.assertEqual("warning", finding["status"])
            self.assertEqual(["photos"], finding["evidence"]["old_values"])
            self.assertEqual(["photo-storage"], finding["evidence"]["new_values"])

    def test_changed_scope_does_not_fail_on_unchanged_baseline_debt(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            subprocess.run(["git", "config", "user.email", "test@example.com"], cwd=root, check=True)
            subprocess.run(["git", "config", "user.name", "Test"], cwd=root, check=True)
            (root / "legacy.yaml").write_text("image: example/app:latest\n", encoding="utf-8")
            base = commit(root, "legacy baseline")
            (root / "README.md").write_text("Documentation only\n", encoding="utf-8")
            commit(root, "docs")
            report = module.collect(root, base, "HEAD")
            self.assertEqual("changed", report["scope"])
            self.assertEqual(0, report["summary"]["findings"])

    def test_helm_secret_expression_is_not_literal_secret_data(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            secret = root / "application/example/templates/secret.yaml"
            secret.parent.mkdir(parents=True)
            secret.write_text(
                "apiVersion: v1\nkind: Secret\nstringData:\n  password: {{ .Values.password | quote }}\n",
                encoding="utf-8",
            )
            report = module.collect(root, None, "HEAD")
            self.assertNotIn("HS-SEC-001", {item["rule_id"] for item in report["findings"]})

    def test_commented_latest_example_is_not_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "values.yaml").write_text("# image: example/app:latest\nimage: example/app:1.2.3\n", encoding="utf-8")
            report = module.collect(root, None, "HEAD")
            self.assertEqual(0, report["summary"]["findings"])


if __name__ == "__main__":
    unittest.main()
