# Agent Executor Runbook v0

Purpose: run project/agent_executor_v0 tasks deterministically with Level 2 track-only quality checks.

## Scope
- Project scope: project/agent_executor_v0
- Parent scope: project/dan_personal_cognitive_infrastructure
- Enforcement: track-only, non-blocking

## Required State
- state/agent_executor/ledger.jsonl
- state/agent_executor/cursor.json
- One task file in scenes/task/

## Invariant Targets
- inv/agent_resumption_min_8
- inv/derived_view_integrity
- inv/observability_entropy

## Execution Steps
1. Load scene and contract:
   - scenes/agent_executor_v0.scene.json
   - meta/AGENT_EXECUTOR_CONTRACT_v0.md
2. Select one task file from scenes/task/.
3. Run preflight claim check (warning-only):
   - tools/sb_coord_claim_preflight_v0.sh --path <target> --actor <agent> --mode claim
4. Append claim:
   - tools/sb_coord_claim_append_v0.sh --path <target> --actor <agent>
5. Update state/agent_executor/cursor.json to the active task and phase.
6. Execute bounded task loop (3-5 iterations unless task explicitly overrides).
7. Append checkpoint events to state/agent_executor/ledger.jsonl.
8. Run scoped quality checks from scenes/agent_executor_quality_gate_v0.scene.json.
9. Emit output artifacts only under allowed output paths.
10. Set cursor phase to done or blocked and record final checkpoint.

## Failure Classification
- level_1_warning: quality warning, run may continue.
- level_2_rework: output invalid against contract; rewrite output.
- level_3_blocked: external dependency or missing input; record blocker and stop.

## Cold Resume Procedure
1. Read state/agent_executor/cursor.json.
2. Read latest entries from state/agent_executor/ledger.jsonl.
3. Re-open referenced task file from scenes/task/.
4. Continue from recorded phase; do not infer hidden state from chat logs.

## Non-Goals
- No global orchestration.
- No cross-project hard gating.
- No automatic mutation outside agent scope.
