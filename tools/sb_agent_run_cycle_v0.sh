#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

AGENT_ID=""
TARGETS_CSV=""
REASON=""
TASK_ID=""
PHASE="cycle_complete"
MUTATION_TYPE="UPDATE"
INPUTS_CSV=""
EXEC_CMD=""
ACTOR=""
REGISTRY_FILE="${REPO_ROOT}/scene/authority/registry_v0.json"
LEDGER_FILE="${REPO_ROOT}/scene/ledger/mutations_v0.jsonl"
SKIP_AUTHORITY_CHECK=0
DRY_RUN=0

usage() {
  cat <<USAGE
Usage: $(basename "$0") --agent-id <agent/<name>_vN> --targets <csv> --reason <text> [options]

Wraps agent run steps 3-5 in one command:
3) claim preflight + append claim for each target
4) execute one cycle command (optional)
5) append mutation ledger records + update agent cursor

Options:
  --agent-id <id>            Required, e.g. agent/project_manager_v0
  --targets <csv>            Required, repo-relative paths (comma-separated)
  --reason <text>            Required, short mutation reason
  --task-id <id>             Optional task id for cursor
  --phase <phase>            Optional cursor phase (default: cycle_complete)
  --mutation-type <type>     Optional (default: UPDATE)
  --inputs <csv>             Optional scene/input refs for ledger entries
  --exec-cmd <cmd>           Optional shell command to run between claim and ledger write
  --actor <name>             Optional claim actor alias (default derived from agent id)
  --registry-file <path>     Optional authority registry path
  --ledger-file <path>       Optional mutation ledger path
  --skip-authority-check     Optional; bypass scoped authority check
  --dry-run                  Print plan only, no file mutation
  -h, --help                 Show help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-id)
      AGENT_ID="$2"; shift 2 ;;
    --targets)
      TARGETS_CSV="$2"; shift 2 ;;
    --reason)
      REASON="$2"; shift 2 ;;
    --task-id)
      TASK_ID="$2"; shift 2 ;;
    --phase)
      PHASE="$2"; shift 2 ;;
    --mutation-type)
      MUTATION_TYPE="$2"; shift 2 ;;
    --inputs)
      INPUTS_CSV="$2"; shift 2 ;;
    --exec-cmd)
      EXEC_CMD="$2"; shift 2 ;;
    --actor)
      ACTOR="$2"; shift 2 ;;
    --registry-file)
      REGISTRY_FILE="$2"; shift 2 ;;
    --ledger-file)
      LEDGER_FILE="$2"; shift 2 ;;
    --skip-authority-check)
      SKIP_AUTHORITY_CHECK=1; shift ;;
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

if [[ -z "${AGENT_ID}" || -z "${TARGETS_CSV}" || -z "${REASON}" ]]; then
  echo "--agent-id, --targets, and --reason are required" >&2
  usage >&2
  exit 1
fi

cd "${REPO_ROOT}"
mkdir -p "$(dirname "${LEDGER_FILE}")"
touch "${LEDGER_FILE}"

PLAN_JSON="$({ python3 - "$REPO_ROOT" "$AGENT_ID" "$TARGETS_CSV" "$ACTOR" "$REGISTRY_FILE" "$MUTATION_TYPE" "$SKIP_AUTHORITY_CHECK" "$INPUTS_CSV" "$REASON" "$TASK_ID" "$PHASE" "$LEDGER_FILE" "$DRY_RUN" <<'PY'
import json
import re
import sys
from pathlib import Path, PurePosixPath

(
    repo_root_raw,
    agent_id,
    targets_csv,
    actor_in,
    registry_file_raw,
    mutation_type,
    skip_authority_raw,
    inputs_csv,
    reason,
    task_id,
    phase,
    ledger_file_raw,
    dry_run_raw,
) = sys.argv[1:]

repo_root = Path(repo_root_raw).resolve()
registry_file = Path(registry_file_raw)
ledger_file = Path(ledger_file_raw)
skip_authority = skip_authority_raw == "1"
dry_run = dry_run_raw == "1"

m = re.match(r"^agent/([a-z0-9_]+)_(v[0-9]+)$", agent_id)
if not m:
    raise SystemExit("--agent-id must match agent/<name>_vN")
agent_base, version = m.group(1), m.group(2)

cursor_rel = f"scene/agent/{agent_base}/cursor_{version}.json"
cursor_abs = (repo_root / cursor_rel).resolve()
if not cursor_abs.exists():
    raise SystemExit(f"cursor file not found: {cursor_rel}")

actor = actor_in.strip() if actor_in.strip() else agent_id.replace("/", "_")
if not re.match(r"^[A-Za-z0-9._-]+$", actor):
    raise SystemExit("derived/provided actor alias is invalid for claim scripts")

raw_targets = [t.strip() for t in targets_csv.split(",") if t.strip()]
if not raw_targets:
    raise SystemExit("--targets must contain at least one path")

# Ensure cursor always gets updated/claimed in cycle step 5.
if cursor_rel not in raw_targets:
    raw_targets.append(cursor_rel)

norm_targets = []
seen = set()
for t in raw_targets:
    if t.startswith("./") or t.startswith("/") or "\\" in t:
        raise SystemExit(f"invalid target path: {t}")
    norm = str(PurePosixPath(t))
    if norm != t or norm.startswith("../") or "/../" in norm or norm == "..":
        raise SystemExit(f"invalid target path: {t}")
    abs_t = (repo_root / norm).resolve()
    if repo_root not in abs_t.parents and abs_t != repo_root:
        raise SystemExit(f"target escapes repo root: {t}")
    if not abs_t.exists():
        raise SystemExit(f"target path does not exist: {t}")
    if norm not in seen:
        norm_targets.append(norm)
        seen.add(norm)

if not registry_file.exists():
    raise SystemExit(f"registry file not found: {registry_file}")

if not skip_authority:
    reg = json.loads(registry_file.read_text(encoding="utf-8"))
    tuples = reg.get("authority_tuples", []) if isinstance(reg, dict) else []
    agent_tuples = [t for t in tuples if isinstance(t, dict) and t.get("agent_id") == agent_id]

    allowed_scopes = []
    for t in agent_tuples:
        muts = t.get("allowed_mutations", [])
        if not isinstance(muts, list):
            continue
        if mutation_type not in muts and "UPDATE" not in muts:
            continue
        scopes = t.get("scope", [])
        if isinstance(scopes, list):
            allowed_scopes.extend([s for s in scopes if isinstance(s, str)])

    def scoped(target: str) -> bool:
        for scope in allowed_scopes:
            if scope.endswith("/") and target.startswith(scope):
                return True
            if target == scope:
                return True
            if target.startswith(scope) and scope in {"scene/", "spec/", "project/", "inv/"}:
                return True
        return False

    unauthorized = [t for t in norm_targets if not scoped(t)]
    if unauthorized:
        raise SystemExit("authority check failed for targets: " + ", ".join(unauthorized))

inputs = [x.strip() for x in inputs_csv.split(",") if x.strip()]

plan = {
    "agent_id": agent_id,
    "actor": actor,
    "targets": norm_targets,
    "cursor_path": cursor_rel,
    "reason": reason,
    "task_id": task_id or None,
    "phase": phase,
    "mutation_type": mutation_type,
    "inputs": inputs,
    "registry_file": str(registry_file),
    "ledger_file": str(ledger_file),
    "dry_run": dry_run,
}
print(json.dumps(plan))
PY
} )"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "$PLAN_JSON" | jq .
  exit 0
fi

mapfile -t TARGETS < <(echo "$PLAN_JSON" | jq -r '.targets[]')
ACTOR_USE="$(echo "$PLAN_JSON" | jq -r '.actor')"
CURSOR_PATH="$(echo "$PLAN_JSON" | jq -r '.cursor_path')"

for target in "${TARGETS[@]}"; do
  tools/sb_coord_claim_preflight_v0.sh --path "$target" --actor "$ACTOR_USE" --mode edit >/dev/null
  tools/sb_coord_claim_append_v0.sh --path "$target" --actor "$ACTOR_USE" >/dev/null
done

declare -A PRE_HASH
for target in "${TARGETS[@]}"; do
  PRE_HASH["$target"]="$(sha256sum "$target" | awk '{print $1}')"
done

if [[ -n "$EXEC_CMD" ]]; then
  bash -lc "$EXEC_CMD"
fi

RUN_JSON="$({ python3 - "$PLAN_JSON" <<'PY'
import json
import sys
from datetime import datetime, timezone

plan = json.loads(sys.argv[1])
now = datetime.now(timezone.utc)
plan["timestamp"] = now.replace(microsecond=0).isoformat().replace("+00:00", "Z")
plan["stamp"] = now.strftime("%Y%m%dT%H%M%SZ")
print(json.dumps(plan))
PY
} )"

LAST_MUTATION_ID=""
idx=0
while IFS= read -r target; do
  idx=$((idx + 1))
  mid="$(echo "$RUN_JSON" | jq -r --argjson i "$idx" '.stamp as $s | .agent_id as $a | "mut_" + $s + "_" + ($a|gsub("/";"_")) + "_" + ($i|tostring)')"
  LAST_MUTATION_ID="$mid"
done < <(echo "$RUN_JSON" | jq -r '.targets[]')

python3 - "${REPO_ROOT}/${CURSOR_PATH}" "$LAST_MUTATION_ID" "$(echo "$RUN_JSON" | jq -r '.timestamp')" "$(echo "$RUN_JSON" | jq -r '.phase')" "$(echo "$RUN_JSON" | jq -r '.task_id // ""')" <<'PY'
import json
import sys
from pathlib import Path

cursor_path = Path(sys.argv[1])
last_mutation_id = sys.argv[2]
ts = sys.argv[3]
phase = sys.argv[4]
task_id = sys.argv[5]

obj = json.loads(cursor_path.read_text(encoding="utf-8"))
obj["phase"] = phase
obj["last_mutation_id"] = last_mutation_id
obj["last_updated"] = ts
if task_id:
    obj["current_task_id"] = task_id
cursor_path.write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")
PY

declare -A POST_HASH
for target in "${TARGETS[@]}"; do
  POST_HASH["$target"]="$(sha256sum "$target" | awk '{print $1}')"
done

PRE_JSON='{}'
POST_JSON='{}'
for target in "${TARGETS[@]}"; do
  PRE_JSON="$(echo "${PRE_JSON}" | jq --arg k "$target" --arg v "${PRE_HASH[$target]}" '. + {($k): $v}')"
  POST_JSON="$(echo "${POST_JSON}" | jq --arg k "$target" --arg v "${POST_HASH[$target]}" '. + {($k): $v}')"
done

python3 - "$RUN_JSON" "$LEDGER_FILE" "$PRE_JSON" "$POST_JSON" <<'PY'
import json
import sys
from pathlib import Path

run = json.loads(sys.argv[1])
ledger_path = Path(sys.argv[2])
pre_hash = json.loads(sys.argv[3])
post_hash = json.loads(sys.argv[4])

ledger_path.parent.mkdir(parents=True, exist_ok=True)
with ledger_path.open("a", encoding="utf-8") as f:
    for i, target in enumerate(run["targets"], start=1):
        mutation_id = f"mut_{run['stamp']}_{run['agent_id'].replace('/', '_')}_{i}"
        row = {
            "mutation_id": mutation_id,
            "timestamp": run["timestamp"],
            "agent_id": run["agent_id"],
            "target_path": target,
            "mutation_type": run["mutation_type"],
            "inputs": run["inputs"],
            "reason": run["reason"],
            "pre_hash": f"sha256:{pre_hash.get(target)}",
            "post_hash": f"sha256:{post_hash.get(target)}",
            "gate_status": "not_evaluated",
        }
        f.write(json.dumps(row, separators=(",", ":")) + "\n")
PY

echo "$RUN_JSON" | jq '{agent_id, actor, targets, mutation_type, phase, task_id, timestamp}'
