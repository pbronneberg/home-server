#!/usr/bin/env python3
from __future__ import annotations
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MONITORING = ROOT / "clusters/home/infrastructure/monitoring"
DASHBOARDS = MONITORING / "dashboards"
REQUIRED_DASHBOARDS = {"home-platform-overview", "home-longhorn-storage", "home-gitops-certificates"}
REQUIRED_RECORDS = {
    "home:cluster_cpu_usage:ratio", "home:cluster_memory_usage:ratio",
    "home:workload_restarts:1h", "home:longhorn_volume_usage:ratio",
    "home:flux_not_ready:count", "home:certificate_min_expiry_seconds",
    "home:autoscaler_workers_sleeping:count", "home:unexpected_targets_down:count",
}
REQUIRED_ALERTS = {
    "AlwaysOnNodeNotReady", "AutoscaledNodeUnexpectedlyOffline",
    "AutoscalerDesiredStateUnknown", "HomeTargetDown",
}
DISABLED_GENERIC_ALERTS = {
    "KubeControllerManagerDown", "KubeSchedulerDown", "KubeProxyDown",
    "KubeNodeNotReady", "TargetDown",
}

def main() -> int:
    errors=[]; seen=set(); dashboards={}
    for path in sorted(DASHBOARDS.glob("*.json")):
        try: dashboard=json.loads(path.read_text(encoding="utf-8"))
        except (OSError,json.JSONDecodeError) as exc:
            errors.append(f"{path.relative_to(ROOT)}: invalid JSON: {exc}"); continue
        uid=dashboard.get("uid")
        if not isinstance(uid,str) or not uid: errors.append(f"{path.relative_to(ROOT)}: missing stable uid")
        elif uid in seen: errors.append(f"{path.relative_to(ROOT)}: duplicate uid {uid}")
        else: seen.add(uid); dashboards[uid]=dashboard
        if dashboard.get("editable") is not False: errors.append(f"{path.relative_to(ROOT)}: provisioned dashboard must be non-editable")
        if "home" not in dashboard.get("tags",[]): errors.append(f"{path.relative_to(ROOT)}: missing home tag")
    missing=REQUIRED_DASHBOARDS-seen
    if missing: errors.append(f"missing dashboards: {', '.join(sorted(missing))}")

    overview=dashboards.get("home-platform-overview",{})
    titles={p.get("title") for p in overview.get("panels",[])}
    for title in ["Actionable platform status","Action required","Expected power-saving state","Unexpected scrape targets down"]:
        if title not in titles: errors.append(f"home-platform-overview: missing required panel {title}")
    serialized=json.dumps(overview)
    for token in ["home_autoscaler_node_info", "desired_power_state", "AutoscaledNodeUnexpectedlyOffline"]:
        if token not in serialized: errors.append(f"home-platform-overview: missing autoscaler-aware query token {token}")

    rules=(MONITORING/"rules/home-platform-rules.yaml").read_text(encoding="utf-8")
    for record in sorted(REQUIRED_RECORDS):
        if f"record: {record}" not in rules: errors.append(f"recording rule missing: {record}")
    for alert in sorted(REQUIRED_ALERTS):
        if f"alert: {alert}" not in rules: errors.append(f"autoscaler-aware alert missing: {alert}")

    values=(MONITORING/"observability-values.yaml").read_text(encoding="utf-8")
    for alert in sorted(DISABLED_GENERIC_ALERTS):
        if f"{alert}: true" not in values: errors.append(f"generic alert must be disabled: {alert}")
    for token in ["infra.homecluster.dev", "home_autoscaler", "desired_power_state: [spec, powerState]"]:
        if token not in values: errors.append(f"autoscaler metric configuration missing: {token}")

    if errors:
        print("Observability validation failed:",file=sys.stderr)
        for error in errors: print(f"- {error}",file=sys.stderr)
        return 1
    print(f"Validated {len(seen)} dashboards, {len(REQUIRED_RECORDS)} recording rules, and {len(REQUIRED_ALERTS)} autoscaler-aware alerts.")
    return 0

if __name__ == "__main__": raise SystemExit(main())
