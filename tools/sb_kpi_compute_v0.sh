#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Namespace boundary declaration (spec/scene_namespace_boundary_v0.md)
TARGET_NAMESPACE="mixed"
ALLOWED_PATH_PREFIXES=("reports/")
BOUNDARY_JUSTIFICATION="KPI dashboard outputs are derived metrics persisted under reports/."

OUT_FILE="${REPO_ROOT}/reports/kpi_dashboard_metrics_v0.json"
SESSIONS_DIR="${REPO_ROOT}/sessions"
GRAPH_FILE="${REPO_ROOT}/graph/graph.json"
CORE_ID="project/dan_personal_cognitive_infrastructure"
COORD_KPI_FILE="${REPO_ROOT}/state/coord_kpi_v0.json"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--out-file <path>] [--sessions-dir <path>] [--graph-file <path>] [--core-id <project-id>] [--coord-kpi-file <path>] [--full-scan]

Computes KPI dashboard metrics from local second-brain files.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-file)
      OUT_FILE="$2"; shift 2 ;;
    --sessions-dir)
      SESSIONS_DIR="$2"; shift 2 ;;
    --graph-file)
      GRAPH_FILE="$2"; shift 2 ;;
    --core-id)
      CORE_ID="$2"; shift 2 ;;
    --coord-kpi-file)
      COORD_KPI_FILE="$2"; shift 2 ;;
    --full-scan)
      shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage >&2
      exit 1 ;;
  esac
done

python3 - "$REPO_ROOT" "$SESSIONS_DIR" "$GRAPH_FILE" "$OUT_FILE" "$CORE_ID" "$COORD_KPI_FILE" <<'PY'
import json
import os
import sys
from collections import defaultdict, deque
from datetime import datetime, timezone
from pathlib import Path

repo_root, sessions_dir, graph_file, out_file, core_id, coord_kpi_file = sys.argv[1:7]


def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

# Canonical principle IDs from scenes.
principles = set()
scenes_dir = os.path.join(repo_root, "scenes")
if os.path.isdir(scenes_dir):
    for n in sorted(os.listdir(scenes_dir)):
        if not n.endswith(".scene.json"):
            continue
        p = os.path.join(scenes_dir, n)
        try:
            s = load_json(p)
        except Exception:
            continue
        nodes = s.get("nodes") if isinstance(s, dict) else None
        if isinstance(nodes, list):
            for node in nodes:
                if isinstance(node, dict):
                    nid = node.get("id")
                    if isinstance(nid, str) and nid.startswith("principle/"):
                        principles.add(nid)

artifacts = []
for tool in sorted(os.listdir(sessions_dir)) if os.path.isdir(sessions_dir) else []:
    tdir = os.path.join(sessions_dir, tool)
    if not os.path.isdir(tdir):
        continue
    for fn in sorted(os.listdir(tdir)):
        if not fn.endswith(".json") or fn == "index.json":
            continue
        fp = os.path.join(tdir, fn)
        try:
            obj = load_json(fp)
        except Exception:
            continue
        if not isinstance(obj, dict):
            continue

        aid = obj.get("artifact_id") or obj.get("id")
        if not isinstance(aid, str):
            continue

        p_links = []
        if isinstance(obj.get("principle_links"), list):
            p_links.extend([x for x in obj["principle_links"] if isinstance(x, str)])
        links = obj.get("links")
        if isinstance(links, dict) and isinstance(links.get("principles"), list):
            p_links.extend([x for x in links["principles"] if isinstance(x, str)])

        summary = obj.get("summary")
        has_summary = False
        if isinstance(summary, str):
            has_summary = bool(summary.strip())
        elif isinstance(summary, dict):
            hl = summary.get("high_level")
            has_summary = isinstance(hl, str) and bool(hl.strip())

        has_decisions = isinstance(obj.get("key_decisions"), list) and any(
            isinstance(x, str) and x.strip() for x in obj.get("key_decisions", [])
        )
        if not has_decisions and isinstance(summary, dict):
            kd = summary.get("key_decisions")
            has_decisions = isinstance(kd, list) and any(isinstance(x, str) and x.strip() for x in kd)

        has_steps = isinstance(obj.get("next_steps"), list) and any(
            isinstance(x, str) and x.strip() for x in obj.get("next_steps", [])
        )

        rs = obj.get("resumption_score")
        rs = rs if isinstance(rs, int) and 0 <= rs <= 10 else None

        artifacts.append(
            {
                "artifact_id": aid,
                "has_principle": any(x in principles for x in p_links),
                "non_trivial": has_summary and (has_decisions or has_steps),
                "resumption_score": rs,
            }
        )

eligible = [a for a in artifacts if a["non_trivial"]]
with_principle = [a for a in eligible if a["has_principle"]]
principle_linked_pct = round((100.0 * len(with_principle) / len(eligible)), 2) if eligible else 0.0

with_score = [a for a in artifacts if a["resumption_score"] is not None]
closeout_pass_rate = (
    round((100.0 * len([a for a in with_score if a["resumption_score"] >= 6]) / len(with_score)), 2)
    if with_score
    else 0.0
)
resumption_avg = round(sum(a["resumption_score"] for a in with_score) / len(with_score), 2) if with_score else 0.0

orphan_ratio = None
coverage_from_core = None
if os.path.isfile(graph_file):
    try:
        g = load_json(graph_file)
        nodes = g.get("nodes", []) if isinstance(g, dict) else []
        edges = g.get("edges", []) if isinstance(g, dict) else []

        node_ids = [n.get("id") for n in nodes if isinstance(n, dict) and isinstance(n.get("id"), str)]
        node_set = set(node_ids)

        degree = defaultdict(int)
        adj = defaultdict(set)
        for e in edges:
            if not isinstance(e, dict):
                continue
            a = e.get("from")
            b = e.get("to")
            if isinstance(a, str) and isinstance(b, str):
                degree[a] += 1
                degree[b] += 1
                adj[a].add(b)

        if node_set:
            orphans = [n for n in node_set if degree[n] < 1]
            orphan_ratio = round(100.0 * len(orphans) / len(node_set), 2)

            if core_id in node_set:
                q = deque([core_id])
                seen = {core_id}
                while q:
                    cur = q.popleft()
                    for nxt in adj.get(cur, set()):
                        if nxt not in seen:
                            seen.add(nxt)
                            q.append(nxt)
                coverage_from_core = round(100.0 * len(seen) / len(node_set), 2)
            else:
                coverage_from_core = 0.0
    except Exception:
        pass

# health score out of 10
norm_principle = principle_linked_pct / 100.0
norm_pass = closeout_pass_rate / 100.0
norm_resumption = min(1.0, resumption_avg / 10.0) if isinstance(resumption_avg, (int, float)) else 0.0
norm_coverage = (coverage_from_core / 100.0) if isinstance(coverage_from_core, (int, float)) else 0.0
norm_orphan = 1.0 - ((orphan_ratio / 100.0) if isinstance(orphan_ratio, (int, float)) else 0.0)
health_score = round(10.0 * (0.35 * norm_principle + 0.25 * norm_pass + 0.2 * norm_resumption + 0.1 * norm_coverage + 0.1 * norm_orphan), 2)

alerts = []
if principle_linked_pct < 70:
    alerts.append("principle_linked_pct below 70%")
if closeout_pass_rate < 90:
    alerts.append("closeout_pass_rate below 90%")
if resumption_avg < 7.0:
    alerts.append("resumption_avg below 7.0")
if isinstance(orphan_ratio, (int, float)) and orphan_ratio > 10:
    alerts.append("orphan_ratio above 10%")
if isinstance(coverage_from_core, (int, float)) and coverage_from_core < 80:
    alerts.append("coverage_from_core below 80%")

# Trend deltas vs previous dashboard file in same report dir.
report_dir = Path(out_file).resolve().parent
prior_files = sorted([p for p in report_dir.glob("kpi_dashboard_metrics_v0*.json") if str(p) != str(Path(out_file).resolve())])
trend = None
if prior_files:
    try:
        prev = load_json(prior_files[-1])
        prev_metrics = prev.get("metrics", {}) if isinstance(prev, dict) else {}

        def d(key, cur):
            prev_v = prev_metrics.get(key)
            if isinstance(prev_v, (int, float)) and isinstance(cur, (int, float)):
                return round(cur - prev_v, 2)
            return None

        trend = {
            "vs_previous_file": prior_files[-1].name,
            "delta": {
                "principle_linked_pct": d("principle_linked_pct", principle_linked_pct),
                "closeout_pass_rate": d("closeout_pass_rate", closeout_pass_rate),
                "resumption_avg": d("resumption_avg", resumption_avg),
                "orphan_ratio": d("orphan_ratio", orphan_ratio),
                "coverage_from_core": d("coverage_from_core", coverage_from_core),
                "health_score": d("health_score", health_score),
            },
        }
    except Exception:
        trend = None

dashboard_delegability_score = round(
    min(
        10.0,
        0.4 * (principle_linked_pct / 100.0 * 10.0)
        + 0.3 * (closeout_pass_rate / 100.0 * 10.0)
        + 0.2 * resumption_avg
        + 0.1 * health_score,
    ),
    2,
)

coord_kpis = {
    "claims_written": 0,
    "warnings_emitted": 0,
    "edits_without_claim": 0,
}
if os.path.isfile(coord_kpi_file):
    try:
        c = load_json(coord_kpi_file)
        if isinstance(c, dict):
            for k in coord_kpis:
                if isinstance(c.get(k), int):
                    coord_kpis[k] = c[k]
    except Exception:
        pass

if coord_kpis["edits_without_claim"] > 0:
    alerts.append("edits_without_claim above 0")

result = {
    "artifact_id": f"artifact/kpi_dashboard_metrics_{datetime.now(timezone.utc).strftime('%Y_%m_%d')}_v0",
    "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "targets": {
        "principle_linked_pct": ">=70%",
        "closeout_pass_rate": ">=90%",
        "resumption_avg": ">=7.0",
        "orphan_ratio": "<=10%",
        "coverage_from_core": ">=80%",
        "health_score": ">=8.0",
        "edits_without_claim": "==0",
    },
    "metrics": {
        "total_artifacts": len(artifacts),
        "eligible_artifacts": len(eligible),
        "principle_linked_pct": principle_linked_pct,
        "closeout_pass_rate": closeout_pass_rate,
        "resumption_avg": resumption_avg,
        "orphan_ratio": orphan_ratio,
        "coverage_from_core": coverage_from_core,
        "health_score": health_score,
        "claims_written": coord_kpis["claims_written"],
        "warnings_emitted": coord_kpis["warnings_emitted"],
        "edits_without_claim": coord_kpis["edits_without_claim"],
    },
    "dashboard_delegability": {
        "value": dashboard_delegability_score,
        "target": 9.0,
    },
    "alerts": alerts,
    "trend": trend,
}

os.makedirs(os.path.dirname(out_file), exist_ok=True)
with open(out_file, "w", encoding="utf-8") as f:
    json.dump(result, f, indent=2)
    f.write("\n")

print(json.dumps(result, indent=2))
PY
