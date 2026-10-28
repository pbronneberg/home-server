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
    "home-observability-diagnostics",
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
    "home:unexpected_targets_down:count",
}
REQUIRED_ALERTS = {
    "AlwaysOnNodeNotReady",
    "ManualWorkerLifecycleBlocked",
    "ManualWorkerLifecycleFailed",
    "ManualWorkerLifecycleNotRunning",
    "HomeTargetDown",
}
DISABLED_GENERIC_ALERTS = {
    "KubeControllerManagerDown",
    "KubeSchedulerDown",
    "KubeProxyDown",
    "KubeNodeNotReady",
    "TargetDown",
}


def iter_panels(dashboard: dict) -> list[dict]:
    panels: list[dict] = []
    stack = list(dashboard.get("panels", []))
    while stack:
        panel = stack.pop()
        panels.append(panel)
        stack.extend(panel.get("panels", []))
    return panels


def load_dashboards(errors: list[str]) -> dict[str, dict]:
    dashboards: dict[str, dict] = {}
    for path in sorted(DASHBOARDS.glob("*.json")):
        try:
            dashboard = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(f"{path.relative_to(ROOT)}: invalid JSON: {exc}")
            continue

        uid = dashboard.get("uid")
        if not isinstance(uid, str) or not uid:
            errors.append(f"{path.relative_to(ROOT)}: missing stable uid")
            continue
        if uid in dashboards:
            errors.append(f"{path.relative_to(ROOT)}: duplicate uid {uid}")
            continue

        dashboards[uid] = dashboard
        if dashboard.get("editable") is not False:
            errors.append(f"{path.relative_to(ROOT)}: provisioned dashboard must be non-editable")
        if "home" not in dashboard.get("tags", []):
            errors.append(f"{path.relative_to(ROOT)}: missing home tag")
        if not dashboard.get("panels"):
            errors.append(f"{path.relative_to(ROOT)}: contains no panels")

    missing = REQUIRED_DASHBOARDS - dashboards.keys()
    if missing:
        errors.append(f"missing dashboards: {', '.join(sorted(missing))}")
    return dashboards


def require_panels(dashboard: dict, expected: set[str], name: str, errors: list[str]) -> None:
    titles = {panel.get("title") for panel in iter_panels(dashboard)}
    for title in sorted(expected):
        if title not in titles:
            errors.append(f"{name}: missing required panel {title}")


def main() -> int:
    errors: list[str] = []
    dashboards = load_dashboards(errors)

    overview = dashboards.get("home-platform-overview", {})
    require_panels(
        overview,
        {
            "Actionable platform status",
            "Manual worker lifecycle failures",
            "Action required",
        },
        "home-platform-overview",
        errors,
    )
    overview_json = json.dumps(overview)
    for token in [
        "manual-worker-lifecycle",
    ]:
        if token not in overview_json:
            errors.append(f"home-platform-overview: missing self-validation token {token}")

    diagnostics = dashboards.get("home-observability-diagnostics", {})
    require_panels(
        diagnostics,
        {
            "Manual worker lifecycle Jobs",
            "Current critical and warning alerts",
        },
        "home-observability-diagnostics",
        errors,
    )
    diagnostics_json = json.dumps(diagnostics)
    for token in [
        "manual-worker-lifecycle",
    ]:
        if token not in diagnostics_json:
            errors.append(f"home-observability-diagnostics: missing diagnostic query token {token}")

    rules = (MONITORING / "rules/home-platform-rules.yaml").read_text(encoding="utf-8")
    for record in sorted(REQUIRED_RECORDS):
        if f"record: {record}" not in rules:
            errors.append(f"recording rule missing: {record}")
    for alert in sorted(REQUIRED_ALERTS):
        if f"alert: {alert}" not in rules:
            errors.append(f"manual-worker lifecycle alert missing: {alert}")

    values = (MONITORING / "observability-values.yaml").read_text(encoding="utf-8")
    for alert in sorted(DISABLED_GENERIC_ALERTS):
        if f"{alert}: true" not in values:
            errors.append(f"generic alert must be disabled: {alert}")
    if "infra.homecluster.dev" in values or "home_autoscaler" in values:
        errors.append("retired autoscaler metric configuration remains")

    kustomization = (MONITORING / "kustomization.yaml").read_text(encoding="utf-8")
    for dashboard_path in sorted(DASHBOARDS.glob("*.json")):
        if dashboard_path.name not in kustomization:
            errors.append(f"dashboard not provisioned by kustomization: {dashboard_path.name}")

    if errors:
        print("Observability validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(
        f"Validated {len(dashboards)} dashboards, "
        f"{len(REQUIRED_RECORDS)} recording rules, and "
        f"{len(REQUIRED_ALERTS)} lifecycle alerts."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
