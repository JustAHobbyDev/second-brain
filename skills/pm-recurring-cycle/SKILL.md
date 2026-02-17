---
name: pm-recurring-cycle
description: Run deterministic project-manager recurring consultation cycles in project/second-brain. Use only for explicit PM-cycle intents such as "run PM recurring cycle", "consult project manager", "resolve PM consultation", or "advance PM stage/task state" via tools/sb_agent_run_cycle_v0.sh. Do not use for direct feature execution or non-PM workflows.
---

# PM Recurring Cycle

## Outcome

Run one PM loop that keeps stage visibility current, asks or resolves exactly one consultation decision, and records all mutations in scene artifacts and the mutation ledger.

## Required State Surfaces

- `scene/agent/project_manager/status_v0.json`
- `scene/agent/project_manager/ideas_v0.json`
- `scene/agent/project_manager/consultation_queue_v0.json`
- `scene/task_queue/v0.json`
- `scene/authority/registry_v0.json`
- `scene/ledger/mutations_v0.jsonl`

## Trigger Boundaries

- Trigger on explicit PM governance-cycle requests.
- Trigger when the user asks to resolve numbered PM consultation choices.
- Skip when the user asks for implementation work outside PM state orchestration.
- Use `references/branch_templates.md` for deterministic field-level branch updates.

## Cycle Workflow

1) Inspect current state and pending consultation.

```bash
jq '.stage_summary, .signals, .next_consultation_due' scene/agent/project_manager/status_v0.json
jq '.items[] | select(.state=="pending")' scene/agent/project_manager/consultation_queue_v0.json
jq '.tasks[] | select(.owner_agent=="agent/project_manager_v0") | {task_id,state,last_progress_at}' scene/task_queue/v0.json
```

2) Select exactly one branch:
- `consult`: resolve one pending consultation from an explicit user choice.
- `kickoff`: if none pending, add one next consultation and update stage focus.
- `status-only`: refresh stage signals with no new consultation.

3) Apply updates via a small local Python mutator script (write only target files).

4) Execute one deterministic wrapper cycle (never write tracked artifacts directly):

```bash
./tools/sb_agent_run_cycle_v0.sh \
  --agent-id agent/project_manager_v0 \
  --targets scene/agent/project_manager/status_v0.json,scene/agent/project_manager/ideas_v0.json,scene/agent/project_manager/consultation_queue_v0.json,scene/task_queue/v0.json \
  --reason "<pm cycle reason>" \
  --task-id task/project-manager-recurring-cycle-v0 \
  --phase <phase_slug> \
  --mutation-type UPDATE \
  --inputs OPEN_QUESTIONS.md,scene/task_queue/v0.json,scene/agent/project_manager/consultation_queue_v0.json \
  --exec-cmd "python3 /tmp/<mutator>.py"
```

5) Verify and report:

```bash
jq '.items[] | select(.state=="pending")' scene/agent/project_manager/consultation_queue_v0.json
jq '.stage_summary, .signals' scene/agent/project_manager/status_v0.json
jq '.tasks[] | select(.task_id=="task/project-manager-recurring-cycle-v0" or .task_id=="task/oq3-autonomy-risk-policy-propose-v0") | {task_id,state,last_progress_at}' scene/task_queue/v0.json
tail -n 5 scene/ledger/mutations_v0.jsonl
```

## Decision Contract

- Keep PM in delegator/planner mode by default.
- Consult the human before high-impact changes.
- Resolve only one consultation per cycle unless user asks for batching.
- Keep mutations scoped to PM scene surfaces and assigned task rows.

## Output Contract

- Return:
  - what decision was processed,
  - which files changed,
  - resulting task/stage state,
  - the next explicit choice for the human.
