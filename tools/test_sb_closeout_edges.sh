#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "${TEST_ROOT}"' EXIT

PASS_JSON="${TEST_ROOT}/pass.json"
FAIL_JSON="${TEST_ROOT}/fail.json"

cat > "${FAIL_JSON}" <<'JSON'
{
  "artifact_id": "artifact/codex_2026_02_15_low-score-rejection-test",
  "session_date": "2026-02-15",
  "llm_used": "codex",
  "project_links": ["project/second_brain_build"],
  "principle_links": ["principle/principles_over_rules", "principle/system_as_infrastructure"],
  "pattern_links": ["pattern/session_artifact_resumption_loop"],
  "tool_links": ["tool/codex"],
  "related_artifact_links": ["artifact/test_ref"],
  "summary": "low score rejection test",
  "key_decisions": ["test decision"],
  "open_questions": ["1. test?"],
  "next_steps": ["test step"],
  "thinking_trace_attachments": ["test trace"],
  "prompt_lineage": [{"role": "user", "summary": "test"}],
  "resumption_score": 5,
  "resumption_notes": "insufficient"
}
JSON

cat > "${PASS_JSON}" <<'JSON'
{
  "artifact_id": "artifact/codex_2026_02_15_alias-and-pass-test",
  "session_date": "2026-02-15",
  "llm_used": "codex",
  "project_links": ["project/second_brain_build"],
  "principle_links": ["principle/principles_over_rules", "principle/system_as_infrastructure"],
  "pattern_links": ["pattern/session_artifact_resumption_loop"],
  "tool_links": ["tool/codex"],
  "related_artifact_links": ["artifact/test_ref"],
  "summary": "pass test",
  "key_decisions": ["test decision"],
  "open_questions": ["1. test?"],
  "next_steps": ["test step"],
  "thinking_trace_attachments": ["test trace"],
  "prompt_lineage": [{"role": "user", "summary": "test"}],
  "resumption_score": 7,
  "resumption_notes": "sufficient"
}
JSON

# Must fail
if "${REPO_ROOT}/tools/sb_closeout.sh" --tool codex --input "${FAIL_JSON}" --sessions-dir "${TEST_ROOT}/sessions" >"${TEST_ROOT}/fail.out" 2>"${TEST_ROOT}/fail.err"; then
  echo "FAIL: low-score artifact unexpectedly passed"
  exit 1
else
  grep -q "resumption_score must be >= 6" "${TEST_ROOT}/fail.err"
fi

# Must pass and alias-resolve
"${REPO_ROOT}/tools/sb_closeout.sh" --tool codex --input "${PASS_JSON}" --sessions-dir "${TEST_ROOT}/sessions" >"${TEST_ROOT}/pass.out"

python3 - <<'PY' "${TEST_ROOT}/sessions/codex/2026-02-15-alias-and-pass-test.json"
import json,sys
p=sys.argv[1]
obj=json.load(open(p))
assert obj["project_links"] == ["project/dan_personal_cognitive_infrastructure"], obj["project_links"]
print("edge_tests_ok")
PY
