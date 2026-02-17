# Agent Executor Contract v0

Version: v0
Status: Draft
Scope: project/agent_executor_v0 (scoped worker under project/dan_personal_cognitive_infrastructure)
Enforcement default: Level 2 (track-only)

## Purpose
Define a deterministic, low-entropy worker contract for executing scoped tasks while preserving cold-resume guarantees.

## Invariant Linkage (existing canonical IDs)
- inv/agent_resumption_min_8
- inv/derived_view_integrity
- inv/observability_entropy

## Inputs (allowed)
- scenes/task/*.json
- scenes/task/*.scene.json
- scenes/*.scene.json (read-only unless explicitly listed in task constraints)
- meta/TERMINOLOGY_STANDARD_v0.md (read-only)
- OPEN_QUESTIONS.md (read-only unless task explicitly allows write)

## Outputs (allowed)
- scenes/task_results/*.json
- scenes/task_results/*.scene.json
- state/agent_executor/ledger.jsonl
- state/agent_executor/cursor.json
- sessions/<tool>/*.json (legacy-only via explicit opt-in closeout)

## Stop Condition
A task run is complete when one of the following is true:
1. All acceptance criteria in the task file are satisfied.
2. The task is blocked and a single explicit blocker reason is written to state/agent_executor/ledger.jsonl.

## Non-Goals
- No global orchestration.
- No autonomous scope expansion.
- No writes outside allowed output paths.
- No hard-gate enforcement (track-only defaults).

## Deterministic Cold Resume Minimum
Resume must be possible from the following files alone:
- state/agent_executor/ledger.jsonl
- state/agent_executor/cursor.json
- referenced task file under scenes/task/

## Validation Procedure (track-only)
1. Confirm all output paths are under allowed prefixes.
2. Confirm each output references at least one source scene/task input.
3. Run scoped quality checks from scenes/agent_executor_quality_gate_v0.scene.json.
4. Emit warnings only; never auto-mutate and never block unrelated projects.

## Versioning Policy
- Schema or contract changes require a new versioned file (for example, AGENT_EXECUTOR_CONTRACT_v1.md).
- Prior versions remain immutable.
