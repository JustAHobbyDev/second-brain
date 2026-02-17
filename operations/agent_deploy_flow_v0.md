# Agent Deploy Flow v0

Purpose: deterministic deployment flow for new agents in this repository.

## Scope
Automates deployment steps 1-4:
1. Define contract spec
2. Create scene/agent state files
3. Mint scoped authority tuples
4. Register recurring task queue entry

## Tool
- `tools/sb_agent_deploy_v0.sh`
- `tools/sb_agent_run_cycle_v0.sh`

## List Deployed Agents
```bash
jq -r '.initial_agents[]' scene/authority/registry_v0.json
```

## Default Behavior
- Scope: `project/dan_personal_cognitive_infrastructure`
- Enforcement: Level 2 track-only
- Role mode: `delegator_planner_non_executor`
- No global hard-gate changes

## Command
```bash
tools/sb_agent_deploy_v0.sh \
  --agent-id agent/<name>_v0
```

## Useful Options
```bash
tools/sb_agent_deploy_v0.sh \
  --agent-id agent/research_planner_v0 \
  --project-scope project/dan_personal_cognitive_infrastructure \
  --issued-by agent/orchestrator_v0 \
  --role-mode delegator_planner_non_executor
```

Dry run:
```bash
tools/sb_agent_deploy_v0.sh --agent-id agent/research_planner_v0 --dry-run
```

## Files Created (if missing)
- `spec/<name>_agent_v0.md`
- `scene/agent/<name>/cursor_v0.json`
- `scene/agent/<name>/status_v0.json`

## Files Updated
- `scene/authority/registry_v0.json`
- `scene/task_queue/v0.json`

## Post-Deploy Checks
1. Validate JSON files with `jq`.
2. Confirm authority tuples are scoped.
3. Confirm recurring task owner matches the new agent ID.
4. Commit and push.

## Run One Cycle (wrapper for steps 3-5)
```bash
tools/sb_agent_run_cycle_v0.sh \
  --agent-id agent/project_manager_v0 \
  --targets scene/agent/project_manager/status_v0.json,scene/agent/project_manager/ideas_v0.json \
  --reason \"pm cycle update\" \
  --task-id task/project-manager-recurring-cycle-v0
```

Dry run:
```bash
tools/sb_agent_run_cycle_v0.sh \
  --agent-id agent/project_manager_v0 \
  --targets scene/agent/project_manager/status_v0.json,scene/agent/project_manager/ideas_v0.json \
  --reason \"pm cycle update\" \
  --task-id task/project-manager-recurring-cycle-v0 \
  --dry-run
```
