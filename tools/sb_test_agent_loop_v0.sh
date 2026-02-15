#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TOOL="codex"
SCENARIO=""
FULL=0
OUT_FILE=""

usage() {
  cat <<'EOF'
Usage:
  tools/sb_test_agent_loop_v0.sh [--tool <name>] [--scenario <name> | --full] [--out-file <path>]

Scenarios:
  happy_path
  edge_low_links
  edge_alias_fail

Examples:
  tools/sb_test_agent_loop_v0.sh --full
  tools/sb_test_agent_loop_v0.sh --scenario edge_alias_fail --tool codex
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tool)
      TOOL="$2"
      shift 2
      ;;
    --scenario)
      SCENARIO="$2"
      shift 2
      ;;
    --full)
      FULL=1
      shift
      ;;
    --out-file)
      OUT_FILE="$2"
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

if [[ -n "${SCENARIO}" && "${FULL}" -eq 1 ]]; then
  echo "Use either --scenario or --full, not both." >&2
  exit 1
fi
if [[ -z "${SCENARIO}" && "${FULL}" -ne 1 ]]; then
  FULL=1
fi

DATE_UTC="$(date -u +%Y-%m-%d)"
DATE_ID="${DATE_UTC//-/_}"
TOOL_LC="$(printf '%s' "${TOOL}" | tr '[:upper:]' '[:lower:]')"
if [[ -z "${OUT_FILE}" ]]; then
  OUT_FILE="${REPO_ROOT}/reports/agent_loop_test_run_${DATE_UTC}.json"
fi

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "${TMP_ROOT}"' EXIT
SESSIONS_DIR="${TMP_ROOT}/sessions"
mkdir -p "${SESSIONS_DIR}"

run_case() {
  local scenario="$1"
  local expected="$2" # pass or fail
  local slug="$3"
  local project_link="$4"
  local principles_json="$5"

  local payload="${TMP_ROOT}/${scenario}.json"
  local stdout_file="${TMP_ROOT}/${scenario}.out"
  local stderr_file="${TMP_ROOT}/${scenario}.err"

  cat > "${payload}" <<EOF
{
  "artifact_id": "artifact/${TOOL_LC}_${DATE_ID}_${slug}",
  "session_date": "${DATE_UTC}",
  "llm_used": "${TOOL_LC}",
  "project_links": ["${project_link}"],
  "principle_links": ${principles_json},
  "pattern_links": ["pattern/session_artifact_resumption_loop"],
  "tool_links": ["tool/${TOOL_LC}", "tool/sb_closeout"],
  "related_artifact_links": ["artifact/agent_loop_test_seed_ref"],
  "summary": "Scenario ${scenario} for agent loop testing.",
  "key_decisions": ["Use deterministic closeout payload for scenario ${scenario}."],
  "open_questions": ["1. Should this scenario remain in the default full run set?"],
  "next_steps": ["Run additional scenario variants after baseline pass."],
  "thinking_trace_attachments": ["tools/sb_test_agent_loop_v0.sh"],
  "prompt_lineage": [{"role": "user", "summary": "Run ${scenario} scenario"}],
  "resumption_score": 8,
  "resumption_notes": "Scenario ${scenario} executed in isolated temp sessions dir."
}
EOF

  local start_ts end_ts duration_ms status out_path
  start_ts="$(python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
)"

  if "${REPO_ROOT}/tools/sb_closeout.sh" --tool "${TOOL_LC}" --input "${payload}" --sessions-dir "${SESSIONS_DIR}" >"${stdout_file}" 2>"${stderr_file}"; then
    status="pass"
  else
    status="fail"
  fi

  end_ts="$(python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
)"
  duration_ms="$((end_ts - start_ts))"

  out_path="${SESSIONS_DIR}/${TOOL_LC}/${DATE_UTC}-${slug}.json"

  # Alias resolution assertion for dedicated scenario.
  if [[ "${scenario}" == "edge_alias_fail" && "${status}" == "pass" ]]; then
    python3 - "${out_path}" <<'PY'
import json
import sys
obj = json.load(open(sys.argv[1], "r", encoding="utf-8"))
assert obj.get("project_links") == ["project/dan_personal_cognitive_infrastructure"], obj.get("project_links")
PY
  fi

  python3 - "${TMP_ROOT}/${scenario}.result.json" "${scenario}" "${expected}" "${status}" "${duration_ms}" "${stderr_file}" "${stdout_file}" <<'PY'
import json
import pathlib
import sys

out_path, scenario, expected, status, duration_ms, stderr_file, stdout_file = sys.argv[1:8]
stderr = pathlib.Path(stderr_file).read_text(encoding="utf-8").strip()
stdout = pathlib.Path(stdout_file).read_text(encoding="utf-8").strip()
result = {
    "scenario": scenario,
    "expected": expected,
    "status": status,
    "matched_expectation": (expected == status),
    "duration_ms": int(duration_ms),
    "stdout": stdout,
    "stderr": stderr,
}
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(result, f, indent=2)
    f.write("\n")
PY
}

if [[ "${FULL}" -eq 1 || "${SCENARIO}" == "happy_path" ]]; then
  run_case "happy_path" "pass" "agent-loop-happy-path" "project/dan_personal_cognitive_infrastructure" "[\"principle/principles_over_rules\", \"principle/system_as_infrastructure\"]"
fi

if [[ "${FULL}" -eq 1 || "${SCENARIO}" == "edge_low_links" ]]; then
  run_case "edge_low_links" "fail" "agent-loop-low-links" "project/dan_personal_cognitive_infrastructure" "[\"principle/principles_over_rules\"]"
fi

if [[ "${FULL}" -eq 1 || "${SCENARIO}" == "edge_alias_fail" ]]; then
  run_case "edge_alias_fail" "pass" "agent-loop-alias-remap" "project/second_brain_build" "[\"principle/principles_over_rules\", \"principle/system_as_infrastructure\"]"
fi

python3 - "${TMP_ROOT}" "${OUT_FILE}" "${TOOL_LC}" "${DATE_UTC}" <<'PY'
import json
import pathlib
import sys
from datetime import datetime, timezone

tmp_root, out_file, tool, date_utc = sys.argv[1:5]
tmp = pathlib.Path(tmp_root)
results = []
for p in sorted(tmp.glob("*.result.json")):
    results.append(json.loads(p.read_text(encoding="utf-8")))

total = len(results)
passed = sum(1 for r in results if r["matched_expectation"])
pass_rate = round((100.0 * passed / total), 2) if total else 0.0
avg_duration_ms = round(sum(r["duration_ms"] for r in results) / total, 2) if total else 0.0

artifact_id = f"artifact/{tool}_{date_utc.replace('-', '_')}_agent-loop-test-run"
report = {
    "artifact_id": artifact_id,
    "report_date": date_utc,
    "tool": tool,
    "summary": {
        "total_scenarios": total,
        "matched_expectation": passed,
        "pass_rate": pass_rate,
        "avg_duration_ms": avg_duration_ms,
    },
    "results": results,
    "next_actions": [
        "If pass_rate < 90%, inspect failed scenario stderr and patch closeout/test workflow.",
        "Wire this script into periodic test loop runs via TEST_LOOP=true meta-program route.",
    ],
    "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
}

out_path = pathlib.Path(out_file)
out_path.parent.mkdir(parents=True, exist_ok=True)
out_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(out_path)
PY

