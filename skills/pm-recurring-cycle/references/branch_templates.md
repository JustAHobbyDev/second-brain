# PM Cycle Branch Templates

Use one branch per cycle. Keep mutations scoped to:

- `scene/agent/project_manager/status_v0.json`
- `scene/agent/project_manager/ideas_v0.json`
- `scene/agent/project_manager/consultation_queue_v0.json`
- `scene/task_queue/v0.json`

## consult

Use when a pending consultation exists and user gave an explicit choice.

Minimum updates:

- Resolve selected consultation (`state: resolved`, set `resolution`)
- Update `status_v0.json.stage_summary` for the affected stream
- Append one `decision_log` entry in `status_v0.json`
- Update mapped task row state + `last_progress_at`
- Set next human choice if another decision is needed

Recommended wrapper phase: `consultation_resolved`

## kickoff

Use when no pending consultations exist and PM should advance stage planning.

Minimum updates:

- Refresh `status_v0.json.stage_summary.next_focus`
- Add one new pending consultation item
- Optionally update one idea `stage` and `deliverable_focus`
- Keep tasks unchanged unless kickoff explicitly opens a task transition

Recommended wrapper phase: `cycle_kickoff`

## status-only

Use when user requests a state refresh with no new consultation decision.

Minimum updates:

- Refresh non-decision status signals only (`signals`, timestamps)
- Do not append decision log entries
- Do not create or resolve consultations
- Do not change task state

Recommended wrapper phase: `status_refresh`

## Guardrails

- Resolve exactly one consultation per cycle unless user requested batching.
- Keep PM in `delegator_planner_non_executor` mode.
- Do not mutate files outside declared PM surfaces.
- Always run through `tools/sb_agent_run_cycle_v0.sh` to preserve claims and ledger.
