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
    "home:autoscaler_sleeping_nodes:count",
    "home:autoscaler_unexpectedly_not_ready:count",
}
REQUIRED_ALERTS = {
    "HomeAlwaysOnNodeNotReady",
    "HomeAutoscaledNodeUnexpectedlyNotReady",
}
DISABLED_UPSTREAM_ALERTS = {
    "KubeControllerManagerDown",
    "KubeNodeNotReady",
    "KubeProxyDown",
    "KubeSchedulerDown",
}


def iter_panels(dashboard: dict) -> list[dict]:
    panels: list[dict] = []
    stack = list(dashboard.get("panels", []))
    while stack:
        panel = stack.pop()
        panels.append(panel)
        stack.extend(panel.get("panels", []))
    return panels


def main() -> int:
    errors: list[str] = []
    seen: set[str] = set()
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
        elif uid in seen:
            errors.append(f"{path.relative_to(ROOT)}: duplicate uid {uid}")
        else:
            seen.add(uid)
            dashboards[uid] = dashboard
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

    overview = dashboards.get("home-platform-overview")
    if overview:
        panels = iter_panels(overview)
        titles = {panel.get("title") for panel in panels}
        for title in [
            "Actionable platform status",
            "Action required",
            "Expected power-saving state",
            "Alerts explained by sleeping nodes",
            "Scrape targets currently down",
        ]:
            if title not in titles:
                errors.append(f"home-platform-overview: missing required panel {title}")
        dashboard_json = json.dumps(overview)
        for required in [
            'homelab_autoscaler_node_info{desired_power_state=\\"off\\"}',
            'unless on(node)',
            'and on(node)',
        ]:
            if required not in dashboard_json:
                errors.append(f"home-platform-overview: missing autoscaler-aware query fragment {required}")
        alert_panels = [
            p for p in panels
            if p.get("title") in {"Actionable platform status", "Actionable criticals", "Actionable warnings"}
        ]
        for panel in alert_panels:
            defaults = panel.get("fieldConfig", {}).get("defaults", {})
            if defaults.get("color", {}).get("mode") != "thresholds":
                errors.append(f"home-platform-overview: {panel.get('title')} must use threshold colors")
            if panel.get("options", {}).get("colorMode") != "background":
                errors.append(f"home-platform-overview: {panel.get('title')} must use background severity coloring")

    rules = (MONITORING / "rules/home-platform-rules.yaml").read_text(encoding="utf-8")
    for record in sorted(REQUIRED_RECORDS):
        if f"record: {record}" not in rules:
            errors.append(f"recording rule missing: {record}")
    for alert in sorted(REQUIRED_ALERTS):
        if f"alert: {alert}" not in rules:
            errors.append(f"alerting rule missing: {alert}")

    values = (MONITORING / "observability-values.yaml").read_text(encoding="utf-8")
    for required in [
        "ruleSelectorNilUsesHelmValues: false",
        "ruleSelector: {}",
        "ruleNamespaceSelector: {}",
        "group: infra.homecluster.dev",
        "kind: Node",
        "desired_power_state: [spec, powerState]",
    ]:
        if required not in values:
            errors.append(f"observability configuration missing: {required}")
    for alert in sorted(DISABLED_UPSTREAM_ALERTS):
        if f"{alert}: true" not in values:
            errors.append(f"K3s/autoscaler-incompatible upstream alert not disabled: {alert}")

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
    print(f"Validated {len(seen)} dashboards, {len(REQUIRED_RECORDS)} recording rules, and autoscaler-aware alert policy.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
