#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SESSIONS_DIR="${REPO_ROOT}/sessions"
OUT_FILE="${REPO_ROOT}/reports/terminology_consistency_audit_v0.json"
LIMIT=5

usage() {
  cat <<'EOF'
Usage:
  tools/sb_terminology_scan_v0.sh [--sessions-dir <path>] [--out-file <path>] [--limit <n>]

Scans recent session artifacts for likely terminology conflation:
- taxonomy used with semantic/graph-edge framing
- ontology used as hierarchy-only
- schema used as semantic ontology
- graph treated as source of truth
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sessions-dir)
      SESSIONS_DIR="$2"
      shift 2
      ;;
    --out-file)
      OUT_FILE="$2"
      shift 2
      ;;
    --limit)
      LIMIT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

python3 - "${SESSIONS_DIR}" "${OUT_FILE}" "${LIMIT}" <<'PY'
import json
import re
import sys
from datetime import date, datetime, timezone
from pathlib import Path

sessions_dir = Path(sys.argv[1])
out_file = Path(sys.argv[2])
limit = int(sys.argv[3])

patterns = [
    (
        "taxonomy_semantic_conflation",
        re.compile(r"\btaxonomy\b.{0,60}\b(edge|relationship|semantic|implements|extends|aligned_with)\b", re.IGNORECASE),
        "taxonomy referenced with semantic-edge language; likely ontology/graph term intended",
    ),
    (
        "ontology_hierarchy_only_conflation",
        re.compile(r"\bontology\b.{0,60}\b(tree|hierarchy|is-a only|parent-child only)\b", re.IGNORECASE),
        "ontology described as hierarchy-only; likely taxonomy term intended",
    ),
    (
        "schema_semantics_conflation",
        re.compile(r"\bschema\b.{0,60}\b(semantic|ontology|meaning model)\b", re.IGNORECASE),
        "schema referenced as semantic model; likely ontology term intended",
    ),
    (
        "graph_source_of_truth_conflation",
        re.compile(r"\b(graph|knowledge graph)\b.{0,60}\b(source of truth|primary storage)\b", re.IGNORECASE),
        "graph described as source of truth; scenes should be source of truth",
    ),
]

def artifact_date_key(obj: dict, path: Path) -> str:
    sd = obj.get("session_date")
    if isinstance(sd, str) and re.match(r"^\d{4}-\d{2}-\d{2}$", sd):
        return sd
    m = re.search(r"(\d{4})_(\d{2})_(\d{2})", str(obj.get("artifact_id", "")))
    if m:
        return f"{m.group(1)}-{m.group(2)}-{m.group(3)}"
    m2 = re.search(r"(\d{4})-(\d{2})-(\d{2})", path.name)
    if m2:
        return f"{m2.group(1)}-{m2.group(2)}-{m2.group(3)}"
    return "0000-00-00"

def flatten_text(obj: dict) -> str:
    parts: list[str] = []
    summary = obj.get("summary")
    if isinstance(summary, str):
        parts.append(summary)
    elif isinstance(summary, dict):
        for v in summary.values():
            if isinstance(v, str):
                parts.append(v)
            elif isinstance(v, list):
                parts.extend(str(x) for x in v if isinstance(x, str))
    for key in ("key_decisions", "open_questions", "next_steps", "resumption_notes"):
        v = obj.get(key)
        if isinstance(v, list):
            parts.extend(str(x) for x in v if isinstance(x, str))
        elif isinstance(v, str):
            parts.append(v)
    return "\n".join(parts)

artifacts = []
for tool_dir in sorted([p for p in sessions_dir.iterdir() if p.is_dir()]):
    for p in sorted(tool_dir.glob("*.json")):
        if p.name == "index.json":
            continue
        try:
            obj = json.loads(p.read_text(encoding="utf-8"))
        except Exception:
            continue
        if not isinstance(obj, dict):
            continue
        aid = obj.get("artifact_id") or obj.get("id")
        if not isinstance(aid, str):
            continue
        artifacts.append((artifact_date_key(obj, p), p, aid, obj))

artifacts.sort(key=lambda x: (x[0], x[2]), reverse=True)
scan_set = artifacts[:limit]

violations = []
for dkey, path, aid, obj in scan_set:
    text = flatten_text(obj)
    for vid, regex, desc in patterns:
        m = regex.search(text)
        if m:
            snippet = text[max(0, m.start() - 40): m.end() + 40].replace("\n", " ").strip()
            violations.append(
                {
                    "artifact_id": aid,
                    "artifact_path": str(path.relative_to(sessions_dir.parent)),
                    "violation_id": vid,
                    "description": desc,
                    "snippet": snippet[:220],
                }
            )

fidelity_pct = 100.0
if scan_set:
    unique_bad = {v["artifact_id"] for v in violations}
    fidelity_pct = round(100.0 * (len(scan_set) - len(unique_bad)) / len(scan_set), 2)

report = {
    "artifact_id": f"artifact/terminology_consistency_audit_{date.today().strftime('%Y_%m_%d')}_v0",
    "audit_date": date.today().isoformat(),
    "scope": {
        "sessions_dir": str(sessions_dir),
        "artifacts_scanned": len(scan_set),
        "scan_limit": limit,
    },
    "kpi": {
        "name": "terminology_fidelity_pct",
        "definition": "Percent of scanned artifacts without detected terminology-conflation patterns",
        "target_pct": 100.0,
        "value_pct": fidelity_pct,
        "status": "pass" if fidelity_pct >= 100.0 else "fail",
    },
    "violations": violations,
    "next_actions": [
        "Review flagged snippets and rewrite term usage if conflation is real.",
        "Run this scan in weekly audits and after terminology standard updates.",
    ],
    "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
}

out_file.parent.mkdir(parents=True, exist_ok=True)
out_file.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(out_file)
PY
