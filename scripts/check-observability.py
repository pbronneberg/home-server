#!/usr/bin/env python3
from __future__ import annotations
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MONITORING = ROOT / "clusters/home/infrastructure/monitoring"
DASHBOARDS = MONITORING / "dashboards"
REQUIRED_DASHBOARDS = {
    "home-platform-overview",
    "home-longhorn-storage",
    "home-gitops-certificates",
}
REQUIRED_RECORDS = {
    "home:cluster_cpu_usage:ratio",
    "home:cluster_memory_usage:ratio",
    "home:workload_restarts:1h",
    "home:longhorn_volume_usage:ratio",
    "home:flux_not_ready:count",
    "home:certificate_min_expiry_seconds",
}

def main() -> int:
    errors: list[str] = []
    seen: set[str] = set()
    for path in sorted(DASHBOARDS.glob("*.json")):
        try:
            dashboard = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(f"{path.relative_to(ROOT)}: invalid JSON: {exc}")
            continue
        uid = dashboard.get("uid")
        if not isinstance(uid, str) or not uid:
            errors.append(f"{path.relative_to(ROOT)}: missing stable uid")
        elif uid in seen:
            errors.append(f"{path.relative_to(ROOT)}: duplicate uid {uid}")
        else:
            seen.add(uid)
        if not dashboard.get("title"):
            errors.append(f"{path.relative_to(ROOT)}: missing title")
        if "home" not in dashboard.get("tags", []):
            errors.append(f"{path.relative_to(ROOT)}: missing home tag")
        if dashboard.get("editable") is not False:
            errors.append(f"{path.relative_to(ROOT)}: provisioned dashboard must be non-editable")
        if not dashboard.get("panels"):
            errors.append(f"{path.relative_to(ROOT)}: contains no panels")
    missing = REQUIRED_DASHBOARDS - seen
    if missing:
        errors.append(f"missing dashboards: {', '.join(sorted(missing))}")

    rules = (MONITORING / "rules/home-platform-rules.yaml").read_text(encoding="utf-8")
    for record in sorted(REQUIRED_RECORDS):
        if f"record: {record}" not in rules:
            errors.append(f"recording rule missing: {record}")

    kustomization = (MONITORING / "kustomization.yaml").read_text(encoding="utf-8")
    for dashboard in sorted(DASHBOARDS.glob("*.json")):
        if dashboard.name not in kustomization:
            errors.append(f"dashboard not provisioned by kustomization: {dashboard.name}")
    for required in ["flux-podmonitor.yaml", "grafana-probe.yaml", "home-platform-rules.yaml", "blackbox-exporter.yaml"]:
        if required not in kustomization:
            errors.append(f"monitoring resource not included: {required}")

    if errors:
        print("Observability validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print(f"Validated {len(seen)} dashboards and {len(REQUIRED_RECORDS)} recording rules.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
