#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPORT_PATH="${REPO_ROOT}/reports/vision_alignment_audit_v0.json"
SHELL_REPORT_PATH="${REPO_ROOT}/reports/shell_embedding_audit_v0.json"
NAMESPACE_REPORT_PATH="${REPO_ROOT}/reports/namespace_boundary_audit_v0.json"
TMP_JSON="$(mktemp)"
TOOL="${1:-codex}"

trap 'rm -f "${TMP_JSON}"' EXIT

cd "${REPO_ROOT}"

python3 scripts/run_vision_alignment_audit.py --out-file "${REPORT_PATH}" >/dev/null
python3 scripts/run_shell_embedding_audit.py --out-file "${SHELL_REPORT_PATH}" >/dev/null
python3 scripts/run_namespace_boundary_audit.py --out-file "${NAMESPACE_REPORT_PATH}" >/dev/null

python3 - "${REPORT_PATH}" "${SHELL_REPORT_PATH}" "${NAMESPACE_REPORT_PATH}" "${TMP_JSON}" "${TOOL}" <<'PY'
import json
import sys
from datetime import date

report_path, shell_report_path, namespace_report_path, out_path, tool = sys.argv[1:6]

with open(report_path, "r", encoding="utf-8") as f:
    r = json.load(f)
with open(shell_report_path, "r", encoding="utf-8") as f:
    s = json.load(f)
with open(namespace_report_path, "r", encoding="utf-8") as f:
    n = json.load(f)

today = date.today().isoformat()
today_id = today.replace("-", "_")
slug = "agent-owned-vision-audit-loop"
artifact_id = f"artifact/{tool}_{today_id}_{slug}"

kpi = r.get("kpi", {}) if isinstance(r, dict) else {}
coverage = r.get("coverage", {}) if isinstance(r, dict) else {}
shell_summary = s.get("summary", {}) if isinstance(s, dict) else {}
shell_alerts = s.get("alerts", []) if isinstance(s, dict) else []
ns_summary = n.get("summary", {}) if isinstance(n, dict) else {}
ns_missing = n.get("missing_declarations", []) if isinstance(n, dict) else []

missing = coverage.get("artifacts_missing_principle_link", [])
if not isinstance(missing, list):
    missing = []

next_actions = r.get("next_actions", [])
if not isinstance(next_actions, list):
    next_actions = []
shell_actions = s.get("next_actions", [])
if not isinstance(shell_actions, list):
    shell_actions = []
ns_actions = n.get("next_actions", [])
if not isinstance(ns_actions, list):
    ns_actions = []

open_questions = [
    "1. Which missing-principle artifacts should be remediated first by business impact?",
    "2. Should closeout require strict canonical-ID existence checks in all environments?",
    "3. Which top embedded-python offenders should be extracted first for maintainability?",
    "4. Which mutating tools should be prioritized for TARGET_NAMESPACE declaration remediation?",
]

payload = {
    "artifact_id": artifact_id,
    "session_date": today,
    "llm_used": tool,
    "project_links": ["project/dan_personal_cognitive_infrastructure"],
    "principle_links": [
        "principle/agent_builds_agent_maintains",
        "principle/system_as_infrastructure",
    ],
    "pattern_links": [
        "pattern/session_artifact_resumption_loop",
    ],
    "tool_links": [
        f"tool/{tool}",
        "tool/python3",
        "tool/sb_closeout",
    ],
    "related_artifact_links": [
        r.get("artifact_id", "artifact/vision_alignment_audit_unknown_v0"),
        s.get("artifact_id", "artifact/shell_embedding_audit_unknown_v0"),
        n.get("artifact_id", "artifact/namespace_boundary_audit_unknown_v0"),
    ] + [x for x in missing if isinstance(x, str)],
    "summary": (
        f"Ran agent-owned vision-alignment audit loop. KPI {kpi.get('name')}="
        f"{kpi.get('value_pct')}% with status={kpi.get('status')}. "
        f"Missing-principle artifacts: {len(missing)}. "
        f"Shell embedding audit: {shell_summary.get('bash_with_embedded_python')}/"
        f"{shell_summary.get('total_bash_scripts')} bash scripts embed python; "
        f"status={s.get('status')}. "
        f"Namespace boundary audit: missing_declarations="
        f"{ns_summary.get('missing_declaration_count')}; status={n.get('status')}."
    ),
    "key_decisions": [
        "Execute audit via script first, then close out via sb_closeout to keep loop deterministic",
        "Use principle_linked_artifact_pct as primary anchor KPI until broader graph KPIs stabilize",
        "Keep shell embedding audit track-only; extraction remains planned remediation, not a hard gate",
        "Keep namespace-boundary declaration audit track-only; prioritize incremental remediation",
    ],
    "open_questions": open_questions,
    "next_steps": [
        str(x) for x in next_actions[:3]
    ] + [str(x) for x in shell_actions[:2]] + [str(x) for x in ns_actions[:2]] or ["Add canonical principle links to missing artifacts listed in report"],
    "thinking_trace_attachments": [
        "reports/vision_alignment_audit_v0.json",
        "reports/shell_embedding_audit_v0.json",
        "reports/namespace_boundary_audit_v0.json",
        f"shell_alerts={len(shell_alerts)}",
        f"namespace_missing_declarations={len(ns_missing)}",
    ],
    "prompt_lineage": [
        {"role": "system", "ref": "prompts/meta_program/50_agent_owned_audit.txt", "summary": "agent-owned audit execution contract"},
        {"role": "user", "summary": "Run agent-owned audit loop end-to-end and persist closeout"},
    ],
    "resumption_score": 8,
    "resumption_notes": "Load reports/vision_alignment_audit_v0.json, reports/shell_embedding_audit_v0.json, and reports/namespace_boundary_audit_v0.json first, then remediate listed artifacts and rerun this script.",
}

with open(out_path, "w", encoding="utf-8") as f:
    json.dump(payload, f, indent=2)
    f.write("\n")
PY

./tools/sb_closeout.sh --tool "${TOOL}" --input "${TMP_JSON}" --allow-unknown-ids
