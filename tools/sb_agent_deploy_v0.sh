#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

AGENT_ID=""
PROJECT_SCOPE="project/dan_personal_cognitive_infrastructure"
ISSUED_BY="agent/orchestrator_v0"
ROLE_MODE="delegator_planner_non_executor"
QUEUE_FILE="${REPO_ROOT}/scene/task_queue/v0.json"
REGISTRY_FILE="${REPO_ROOT}/scene/authority/registry_v0.json"
DRY_RUN=0

usage() {
  cat <<USAGE
Usage: $(basename "$0") --agent-id <agent/<name>_vN> [options]

Automates steps 1-4 of agent deployment:
1) create spec contract
2) create scene/agent state files
3) mint authority tuples in scene/authority/registry_v0.json
4) add recurring task in scene/task_queue/v0.json

Options:
  --agent-id <id>          Required, e.g. agent/research_planner_v0
  --project-scope <id>     Optional (default: ${PROJECT_SCOPE})
  --issued-by <agent_id>   Optional (default: ${ISSUED_BY})
  --role-mode <mode>       Optional (default: ${ROLE_MODE})
                           Suggested: delegator_planner_non_executor
  --registry-file <path>   Optional registry file path
  --queue-file <path>      Optional task queue file path
  --dry-run                Validate and print planned actions only
  -h, --help               Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-id)
      AGENT_ID="$2"; shift 2 ;;
    --project-scope)
      PROJECT_SCOPE="$2"; shift 2 ;;
    --issued-by)
      ISSUED_BY="$2"; shift 2 ;;
    --role-mode)
      ROLE_MODE="$2"; shift 2 ;;
    --registry-file)
      REGISTRY_FILE="$2"; shift 2 ;;
    --queue-file)
      QUEUE_FILE="$2"; shift 2 ;;
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

if [[ -z "${AGENT_ID}" ]]; then
  echo "--agent-id is required" >&2
  usage >&2
  exit 1
fi

python3 - "$REPO_ROOT" "$AGENT_ID" "$PROJECT_SCOPE" "$ISSUED_BY" "$ROLE_MODE" "$REGISTRY_FILE" "$QUEUE_FILE" "$DRY_RUN" <<'PY'
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

(
    repo_root_raw,
    agent_id,
    project_scope,
    issued_by,
    role_mode,
    registry_file_raw,
    queue_file_raw,
    dry_run_raw,
) = sys.argv[1:]

repo_root = Path(repo_root_raw).resolve()
registry_file = Path(registry_file_raw)
queue_file = Path(queue_file_raw)
dry_run = dry_run_raw == "1"

agent_re = re.compile(r"^agent/([a-z0-9_]+)_(v[0-9]+)$")
m = agent_re.match(agent_id)
if not m:
    raise SystemExit("--agent-id must match agent/<name>_vN (lowercase snake_case)")

agent_base, version = m.group(1), m.group(2)
agent_dir = repo_root / "scene" / "agent" / agent_base
spec_path = repo_root / "spec" / f"{agent_base}_agent_{version}.md"
cursor_path = agent_dir / f"cursor_{version}.json"
status_path = agent_dir / f"status_{version}.json"

now = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)

def write_if_missing(path: Path, content: str) -> bool:
    if path.exists():
        return False
    ensure_parent(path)
    path.write_text(content, encoding="utf-8")
    return True

spec_template = f"""# {agent_base.replace('_', ' ').title()} Agent {version}

Version: {version}
Status: Draft
Scope: {project_scope}
Enforcement default: Level 2 (track-only)

## Purpose
Define a scoped worker contract for {agent_id}.

## Default Role Mode
- {role_mode}

## Invariant Linkage (existing canonical IDs)
- inv/agent_resumption_min_8
- inv/derived_view_integrity
- inv/observability_entropy

## Inputs (read)
- scene/task_queue/v0.json
- scene/authority/registry_v0.json
- scene/ledger/mutations_v0.jsonl

## Outputs (write, scoped)
- scene/agent/{agent_base}/cursor_{version}.json
- scene/agent/{agent_base}/status_{version}.json
- scene/audit_reports/v0/* (optional, report-only)

## Non-Goals
- No global hard-gate creation.
- No mutation outside scoped authority tuples.
"""

cursor_template = {
    "agent_id": agent_id,
    "role_mode": role_mode,
    "phase": "ready",
    "current_cycle_id": f"{agent_base}_cycle_{version}",
    "current_task_id": f"task/{agent_base}-recurring-cycle-{version}",
    "last_mutation_id": None,
    "last_updated": now,
    "resumption_inputs": [
        f"scene/agent/{agent_base}/status_{version}.json",
        f"scene/agent/{agent_base}/cursor_{version}.json",
        "scene/task_queue/v0.json",
    ],
}

status_template = {
    "status_id": f"scene/agent/{agent_base}/status_{version}",
    "updated_at": now,
    "project_scope": project_scope,
    "role_mode": role_mode,
    "stage_summary": {"overall": "initialized"},
    "signals": {"deployment": "bootstrapped"},
}

planned_creates = []
for p in (spec_path, cursor_path, status_path):
    if not p.exists():
        planned_creates.append(str(p.relative_to(repo_root)))

if not registry_file.exists():
    raise SystemExit(f"registry file not found: {registry_file}")
if not queue_file.exists():
    raise SystemExit(f"queue file not found: {queue_file}")

registry = json.loads(registry_file.read_text(encoding="utf-8"))
if not isinstance(registry, dict):
    raise SystemExit("registry must be a JSON object")
registry.setdefault("initial_agents", [])
registry.setdefault("agent_role_defaults", {})
registry.setdefault("authority_tuples", [])

if agent_id not in registry["initial_agents"]:
    registry["initial_agents"].append(agent_id)
registry["agent_role_defaults"][agent_id] = role_mode

authority_ids = {t.get("authority_id") for t in registry["authority_tuples"] if isinstance(t, dict)}

state_auth_id = f"auth/{agent_base}_state_updates_{version}"
if state_auth_id not in authority_ids:
    registry["authority_tuples"].append(
        {
            "authority_id": state_auth_id,
            "agent_id": agent_id,
            "scope": [
                f"scene/agent/{agent_base}/",
                "scene/task_queue/",
            ],
            "allowed_mutations": ["CREATE", "UPDATE"],
            "conditions": [
                "must_record_mutation",
                "must_update_cursor",
                "scope_only",
                "track_only_behavior",
            ]
            + (["delegator_planner_default_no_execution"] if role_mode.startswith("delegator_planner") else []),
            "issued_by": issued_by,
            "issued_at": now,
            "expires_at": None,
            "revocation": None,
        }
    )

propose_auth_id = f"auth/{agent_base}_proposals_{version}"
if propose_auth_id not in authority_ids:
    registry["authority_tuples"].append(
        {
            "authority_id": propose_auth_id,
            "agent_id": agent_id,
            "scope": ["project/", "spec/", "scene/"],
            "allowed_mutations": ["PROPOSE"],
            "conditions": [
                "must_record_mutation",
                "no_global_gate_changes",
                "human_consultation_required_before_execution",
            ]
            + (["delegator_planner_default_no_execution"] if role_mode.startswith("delegator_planner") else []),
            "issued_by": issued_by,
            "issued_at": now,
            "expires_at": None,
            "revocation": None,
        }
    )

queue = json.loads(queue_file.read_text(encoding="utf-8"))
if not isinstance(queue, dict):
    raise SystemExit("queue file must be a JSON object")
queue.setdefault("tasks", [])

task_id = f"task/{agent_base}-recurring-cycle-{version}"
if not any(isinstance(t, dict) and t.get("task_id") == task_id for t in queue["tasks"]):
    queue["tasks"].insert(
        0,
        {
            "task_id": task_id,
            "objective": f"Run recurring planning cycle for {agent_id} within scoped authority.",
            "inputs": [
                f"scene/agent/{agent_base}/status_{version}.json",
                f"scene/agent/{agent_base}/cursor_{version}.json",
                "scene/task_queue/v0.json",
                "scene/authority/registry_v0.json",
            ],
            "constraints": [
                "Level 2 track-only only",
                "No global gates",
                "No mutation outside scoped authority",
            ]
            + (["Delegator/planner default (non-executor)"] if role_mode.startswith("delegator_planner") else []),
            "acceptance_criteria": [
                "Stage/status updated",
                "Mutation intent recorded as proposal when outside state scope",
                "Cursor remains cold-resume ready",
            ],
            "state": "queued",
            "owner_agent": agent_id,
        },
    )

if dry_run:
    print(json.dumps({
        "dry_run": True,
        "would_create_files": planned_creates,
        "agent_id": agent_id,
        "spec_path": str(spec_path.relative_to(repo_root)),
        "cursor_path": str(cursor_path.relative_to(repo_root)),
        "status_path": str(status_path.relative_to(repo_root)),
        "registry_file": str(registry_file),
        "queue_file": str(queue_file),
    }, indent=2))
    raise SystemExit(0)

created = []
if write_if_missing(spec_path, spec_template):
    created.append(str(spec_path.relative_to(repo_root)))
if write_if_missing(cursor_path, json.dumps(cursor_template, indent=2) + "\n"):
    created.append(str(cursor_path.relative_to(repo_root)))
if write_if_missing(status_path, json.dumps(status_template, indent=2) + "\n"):
    created.append(str(status_path.relative_to(repo_root)))

registry_file.write_text(json.dumps(registry, indent=2) + "\n", encoding="utf-8")
queue_file.write_text(json.dumps(queue, indent=2) + "\n", encoding="utf-8")

print(json.dumps({
    "created_files": created,
    "agent_id": agent_id,
    "updated": [str(registry_file), str(queue_file)],
}, indent=2))
PY
