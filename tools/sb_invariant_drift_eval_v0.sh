#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SCOPE="project/dan_personal_cognitive_infrastructure"
SPEC_FILE="${REPO_ROOT}/spec/invariant_drift_detection_v0.md"
KPI_FILE="${REPO_ROOT}/reports/kpi_dashboard_metrics_v0.json"
GRAPH_FILE="${REPO_ROOT}/graph/graph.json"
OUT_FILE=""
GENERATED_AT=""
DRY_RUN=0

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Emits a track-only invariant drift report at:
  scene/audit_reports/v0/invariant_drift_report_<date>_v0.json

Options:
  --scope <project_id>      Optional scope (default: ${SCOPE})
  --spec-file <path>        Optional spec path
  --kpi-file <path>         Optional KPI source path
  --graph-file <path>       Optional graph source path
  --out-file <path>         Optional output file path
  --generated-at <ts>       Optional RFC3339 timestamp override
  --dry-run                 Print report JSON to stdout; do not write file
  -h, --help                Show help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope)
      SCOPE="$2"; shift 2 ;;
    --spec-file)
      SPEC_FILE="$2"; shift 2 ;;
    --kpi-file)
      KPI_FILE="$2"; shift 2 ;;
    --graph-file)
      GRAPH_FILE="$2"; shift 2 ;;
    --out-file)
      OUT_FILE="$2"; shift 2 ;;
    --generated-at)
      GENERATED_AT="$2"; shift 2 ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage >&2
      exit 1 ;;
  esac
done

python3 - "$REPO_ROOT" "$SCOPE" "$SPEC_FILE" "$KPI_FILE" "$GRAPH_FILE" "$OUT_FILE" "$GENERATED_AT" "$DRY_RUN" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

(
    repo_root_raw,
    scope,
    spec_file_raw,
    kpi_file_raw,
    graph_file_raw,
    out_file_raw,
    generated_at_raw,
    dry_run_raw,
) = sys.argv[1:9]

repo_root = Path(repo_root_raw)
spec_file = Path(spec_file_raw)
kpi_file = Path(kpi_file_raw)
graph_file = Path(graph_file_raw)
dry_run = dry_run_raw == "1"

if generated_at_raw:
    ts_raw = generated_at_raw
    ts_norm = ts_raw[:-1] + "+00:00" if ts_raw.endswith("Z") else ts_raw
    generated_at = datetime.fromisoformat(ts_norm)
    if generated_at.tzinfo is None:
        raise SystemExit("--generated-at must include timezone")
    generated_at = generated_at.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
else:
    generated_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

day_str = generated_at[:10]
default_out = repo_root / "scene" / "audit_reports" / "v0" / f"invariant_drift_report_{day_str}_v0.json"
out_file = Path(out_file_raw) if out_file_raw else default_out

thresholds = {
    "principle_linked_pct": 75.0,
    "orphan_ratio": 10.0,
    "coverage_from_core": 80.0,
}

triggers = [
    {
        "trigger_id": "trigger/coverage_from_core_below_min",
        "metric": "coverage_from_core",
        "source_path": "reports/kpi_dashboard_metrics_v0.json::metrics.coverage_from_core",
        "direction": "min",
        "threshold": thresholds["coverage_from_core"],
        "severity": "high",
        "invariant_links": ["inv/vision_alignment", "inv/derived_view_integrity"],
    },
    {
        "trigger_id": "trigger/orphan_ratio_above_max",
        "metric": "orphan_ratio",
        "source_path": "reports/kpi_dashboard_metrics_v0.json::metrics.orphan_ratio",
        "direction": "max",
        "threshold": thresholds["orphan_ratio"],
        "severity": "medium",
        "invariant_links": ["inv/derived_view_integrity"],
    },
    {
        "trigger_id": "trigger/principle_linked_pct_below_min",
        "metric": "principle_linked_pct",
        "source_path": "reports/kpi_dashboard_metrics_v0.json::metrics.principle_linked_pct",
        "direction": "min",
        "threshold": thresholds["principle_linked_pct"],
        "severity": "high",
        "invariant_links": ["inv/vision_alignment"],
    },
]
triggers.sort(key=lambda x: x["trigger_id"])

source_artifacts = []
if spec_file.exists():
    try:
        source_artifacts.append(str(spec_file.resolve().relative_to(repo_root)))
    except Exception:
        source_artifacts.append(str(spec_file))
if kpi_file.exists():
    try:
        source_artifacts.append(str(kpi_file.resolve().relative_to(repo_root)))
    except Exception:
        source_artifacts.append(str(kpi_file))
if graph_file.exists():
    try:
        source_artifacts.append(str(graph_file.resolve().relative_to(repo_root)))
    except Exception:
        source_artifacts.append(str(graph_file))

kpi_metrics = {}
kpi_error = None
if not kpi_file.exists():
    kpi_error = "missing required input: reports/kpi_dashboard_metrics_v0.json"
else:
    try:
        obj = json.loads(kpi_file.read_text(encoding="utf-8"))
        if not isinstance(obj, dict):
            raise ValueError("KPI file must decode to JSON object")
        metrics = obj.get("metrics")
        if not isinstance(metrics, dict):
            raise ValueError("KPI file missing metrics object")
        kpi_metrics = metrics
    except Exception as e:
        kpi_error = f"unreadable KPI input: {e}"

trigger_events = []
proposed_remediations = []
status_counts = {"pass": 0, "violated": 0, "warning": 0, "insufficient_input": 0}

for trig in triggers:
    observed = kpi_metrics.get(trig["metric"]) if not kpi_error else None
    event = {
        "trigger_id": trig["trigger_id"],
        "metric": trig["metric"],
        "source_path": trig["source_path"],
        "observed": observed if isinstance(observed, (int, float)) else None,
        "threshold": trig["threshold"],
        "status": "",
        "severity": trig["severity"],
        "evaluator_note": "",
        "invariant_links": trig["invariant_links"],
    }

    if kpi_error:
        event["status"] = "insufficient_input"
        event["evaluator_note"] = kpi_error
        status_counts["insufficient_input"] += 1
    elif not isinstance(observed, (int, float)):
        event["status"] = "insufficient_input"
        event["evaluator_note"] = f"missing or non-numeric source field for {trig['metric']}"
        status_counts["insufficient_input"] += 1
    else:
        if trig["direction"] == "min":
            violated = float(observed) < float(trig["threshold"])
        else:
            violated = float(observed) > float(trig["threshold"])
        event["status"] = "violated" if violated else "pass"
        event["evaluator_note"] = ""
        status_counts["violated" if violated else "pass"] += 1

    trigger_events.append(event)

if status_counts["insufficient_input"] > 0:
    proposed_remediations.append(
        "Regenerate reports/kpi_dashboard_metrics_v0.json before running drift evaluation."
    )
if status_counts["violated"] > 0:
    if any(e["trigger_id"] == "trigger/principle_linked_pct_below_min" and e["status"] == "violated" for e in trigger_events):
        proposed_remediations.append(
            "Increase principle linkage coverage in non-trivial session artifacts."
        )
    if any(e["trigger_id"] == "trigger/orphan_ratio_above_max" and e["status"] == "violated" for e in trigger_events):
        proposed_remediations.append(
            "Investigate and connect orphan-like graph nodes to canonical project/principle anchors."
        )
    if any(e["trigger_id"] == "trigger/coverage_from_core_below_min" and e["status"] == "violated" for e in trigger_events):
        proposed_remediations.append(
            "Raise coverage from core by adding typed links from project/dan_personal_cognitive_infrastructure."
        )

recommendation = "pass"
if status_counts["insufficient_input"] > 0:
    recommendation = "insufficient_input"
elif status_counts["violated"] > 0:
    recommendation = "review_required"

report = {
    "artifact_id": f"artifact/invariant_drift_report_{day_str.replace('-', '_')}_v0",
    "schema_version": "0.1",
    "generated_at": generated_at,
    "scope": scope,
    "source_artifacts": sorted(source_artifacts),
    "trigger_events": trigger_events,
    "trigger_summary": {
        "pass": status_counts["pass"],
        "violated": status_counts["violated"],
        "warning": status_counts["warning"],
        "insufficient_input": status_counts["insufficient_input"],
        "overall_status": recommendation,
    },
    "affected_artifacts": [],
    "proposed_remediations": proposed_remediations,
    "invariant_links": [
        "inv/vision_alignment",
        "inv/derived_view_integrity",
        "inv/agents_resume_cold",
        "inv/scenes_source_of_truth",
    ],
    "resumption_score": 9 if recommendation == "pass" else 7,
}

if dry_run:
    print(json.dumps(report, indent=2))
    raise SystemExit(0)

out_file.parent.mkdir(parents=True, exist_ok=True)
out_file.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"out_file": str(out_file), "overall_status": recommendation}, indent=2))
PY
