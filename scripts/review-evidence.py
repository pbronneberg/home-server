#!/usr/bin/env python3
"""Collect deterministic repository review evidence as versioned JSON."""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

SCHEMA_VERSION = "1.0"
SEVERITY_RANK = {"info": 0, "low": 1, "medium": 2, "high": 3, "critical": 4}
YAML_SUFFIXES = {".yaml", ".yml"}
SKIP_PARTS = {".git", ".venv", "node_modules", "private-decrypted", "charts"}

LATEST_RE = re.compile(r"(?:^|[\s\"'])(?:image:\s*[^\s]+:latest|tag:\s*[\"']?latest[\"']?)(?:$|\s)", re.I)
WRITE_ALL_RE = re.compile(r"^\s*permissions\s*:\s*write-all\s*(?:#.*)?$", re.M)
KIND_SECRET_RE = re.compile(r"^\s*kind\s*:\s*Secret\s*(?:#.*)?$", re.M)
SECRET_DATA_RE = re.compile(r"^\s*stringData\s*:\s*(?:\{\s*\})?\s*(?:#.*)?$", re.M)
SENSITIVE_DIFF_RE = re.compile(
    r"^\s*(?P<key>existingClaim|claimName|secretName|host|clusterDomain|githubAppInstallationOwner)\s*:\s*(?P<value>.+?)\s*(?:#.*)?$"
)

@dataclass(frozen=True)
class Finding:
    rule_id: str
    severity: str
    status: str
    message: str
    file: str | None = None
    line: int | None = None
    evidence: dict[str, object] | None = None
    requires_judgment: bool = False


def run_git(root: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args], cwd=root, text=True, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, check=False
    )


def tracked_files(root: Path) -> list[Path]:
    result = run_git(root, "ls-files", "-z")
    if result.returncode != 0:
        return [p for p in root.rglob("*") if p.is_file() and not SKIP_PARTS.intersection(p.parts)]
    return [root / value for value in result.stdout.split("\0") if value]


def line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def inspect_file(root: Path, path: Path) -> list[Finding]:
    rel = path.relative_to(root).as_posix()
    if SKIP_PARTS.intersection(path.relative_to(root).parts):
        return []
    if path.suffix.lower() not in YAML_SUFFIXES:
        return []
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return []

    findings: list[Finding] = []
    match = LATEST_RE.search(text)
    if match:
        findings.append(Finding(
            "HS-IMG-001", "high", "fail",
            "Mutable latest image tag is committed.", rel,
            line_number(text, match.start()),
            {"matched": match.group(0).strip()}, False,
        ))

    if rel.startswith(".github/workflows/"):
        match = WRITE_ALL_RE.search(text)
        if match:
            findings.append(Finding(
                "HS-GHA-001", "critical", "fail",
                "GitHub Actions workflow grants write-all permissions.", rel,
                line_number(text, match.start()), None, False,
            ))

    secret_kind = KIND_SECRET_RE.search(text)
    if not rel.endswith((".sops.yaml", ".sops.yml")) and secret_kind and SECRET_DATA_RE.search(text):
        findings.append(Finding(
            "HS-SEC-001", "critical", "fail",
            "Plaintext Kubernetes Secret manifest is committed outside a SOPS file.",
            rel, line_number(text, secret_kind.start()), None, False,
        ))
    return findings


def resolve_base(root: Path, requested: str | None) -> tuple[str | None, str | None]:
    candidates = [requested, os.environ.get("GITHUB_BASE_REF")]
    if os.environ.get("GITHUB_BASE_REF"):
        candidates.append(f"origin/{os.environ['GITHUB_BASE_REF']}")
    candidates.extend(["HEAD^", "main", "origin/main"])
    for candidate in candidates:
        if not candidate:
            continue
        result = run_git(root, "rev-parse", "--verify", candidate)
        if result.returncode == 0:
            return candidate, result.stdout.strip()
    return None, None


def changed_sensitive_values(root: Path, base: str, head: str) -> list[Finding]:
    result = run_git(root, "diff", "--unified=0", f"{base}...{head}", "--", "*.yaml", "*.yml")
    if result.returncode != 0:
        return []
    findings: list[Finding] = []
    current_file: str | None = None
    removed: dict[str, list[str]] = {}
    added: dict[str, list[str]] = {}

    def flush() -> None:
        nonlocal removed, added
        if not current_file:
            return
        for key in sorted(set(removed) & set(added)):
            old_values = sorted(set(removed[key]))
            new_values = sorted(set(added[key]))
            if old_values == new_values:
                continue
            findings.append(Finding(
                "HS-DIFF-001", "medium", "warning",
                f"Sensitive configuration key '{key}' changed and requires migration or operational review.",
                current_file, None,
                {"key": key, "old_values": old_values, "new_values": new_values}, True,
            ))
        removed, added = {}, {}

    for raw in result.stdout.splitlines():
        if raw.startswith("+++ b/"):
            flush()
            current_file = raw[6:]
            continue
        if raw.startswith(("+++", "---", "@@")):
            continue
        if raw[:1] not in {"+", "-"}:
            continue
        match = SENSITIVE_DIFF_RE.match(raw[1:])
        if not match:
            continue
        bucket = added if raw.startswith("+") else removed
        bucket.setdefault(match.group("key"), []).append(match.group("value").strip().strip("\"'"))
    flush()
    return findings


def collect(root: Path, base: str | None, head: str) -> dict[str, object]:
    findings: list[Finding] = []
    for path in tracked_files(root):
        findings.extend(inspect_file(root, path))

    skipped: list[dict[str, str]] = []
    resolved_base, base_sha = resolve_base(root, base)
    if resolved_base:
        findings.extend(changed_sensitive_values(root, resolved_base, head))
    else:
        skipped.append({
            "id": "sensitive-diff",
            "reason": "No usable base ref was available; static repository checks still ran.",
        })

    findings.sort(key=lambda item: (-SEVERITY_RANK[item.severity], item.rule_id, item.file or ""))
    return {
        "schema_version": SCHEMA_VERSION,
        "repository_root": str(root),
        "base": resolved_base,
        "base_sha": base_sha,
        "head": head,
        "summary": {
            "findings": len(findings),
            "failures": sum(item.status == "fail" for item in findings),
            "warnings": sum(item.status == "warning" for item in findings),
            "requires_judgment": sum(item.requires_judgment for item in findings),
        },
        "findings": [asdict(item) for item in findings],
        "skipped": skipped,
    }


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--base")
    parser.add_argument("--head", default="HEAD")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--fail-on", choices=SEVERITY_RANK, default="high")
    args = parser.parse_args(list(argv) if argv is not None else None)

    root = args.root.resolve()
    report = collect(root, args.base, args.head)
    rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    else:
        sys.stdout.write(rendered)

    threshold = SEVERITY_RANK[args.fail_on]
    return int(any(
        item["status"] == "fail" and SEVERITY_RANK[item["severity"]] >= threshold
        for item in report["findings"]
    ))


if __name__ == "__main__":
    raise SystemExit(main())
