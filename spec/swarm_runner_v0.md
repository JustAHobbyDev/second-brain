# Swarm Runner v0

Version: v0
Status: Draft
Scope: project/dan_personal_cognitive_infrastructure
Enforcement default: Level 2 (track-only)

## Purpose
Define a minimal swarm runner that coordinates parallel specialist agents through runtime surfaces while preserving second-brain canonical boundaries.

This spec defines orchestration behavior only. It does not replace canonical scene architecture.

## Invariant Linkage (existing canonical IDs)
- inv/scenes_source_of_truth
- inv/agents_resume_cold
- inv/derived_view_integrity
- inv/scoped_constraints_preferred
- inv/reduce_entropy_never_increase
- inv/kalshi_data_windows_min_200

## Hard Constraints (v0)

### 1) Fan-out shape
- Single-level fan-out only.
- No nested swarms.
- No autonomous self-spawn behavior.

### 2) Write policy
- Specialist agents may write only runtime surfaces.
- Canonical writes to `scenes/` are allowed only during explicit materialization step.
- Runtime outputs are never treated as canonical truth until materialized.

### 3) Determinism
- Fixed role set per run: `orchestrator`, `scout`, `builder`, `reviewer`, `merger`.
- Deterministic task selection rule must be declared in run manifest.
- Retry policy must be fixed before run start (default: one retry max per specialist).
- No role creation at runtime.

### 4) Auditability
- Every run emits a run manifest, per-agent output references, and a final evaluation artifact.
- Every mutation is attributable in `scene/ledger/mutations_v0.jsonl`.
- Missing required run artifacts marks run status `incomplete`.

## Non-Interference Rule (Kalshi scoped gate)
- Swarm runner must not mutate:
  - `project/kalshi_15m_btc_pipeline`
  - `scenes/kalshi_15m_btc_pipeline.scene.json`
  while Kalshi gate is blocked.
- Gate status source of record:
  - `scenes/kalshi_data_gate_v0.scene.json`
- If blocked scope is detected in selected tasks, runner must:
  - exclude those tasks from execution,
  - emit a warning artifact,
  - continue only with non-blocked scope tasks.
- Swarm runner must not introduce global hard gates.

## Runtime Surfaces (allowed)
- `scene/mailbox/messages_v0.jsonl`
- `scene/mailbox/index_v0.json`
- `scene/merge_queue/queue_v0.json`
- `scene/sandbox/registry_v0.json`
- `scene/ledger/mutations_v0.jsonl`
- `scene/audit_reports/v0/`
- `scene/swarm/` (run-local runtime artifacts)

## Canonical Surfaces (materialization only)
- `scenes/` (decision and outcome artifacts only)

## Proposed Authority Shape (track-only draft)
- `auth/swarm_orchestrator_runtime_v0`
  - scope: `scene/swarm/`, `scene/mailbox/`, `scene/sandbox/`, `scene/merge_queue/`
  - mutations: `CREATE`, `UPDATE`
- `auth/swarm_specialist_runtime_v0`
  - scope: `scene/swarm/`, `scene/mailbox/`
  - mutations: `CREATE`, `UPDATE`, `PROPOSE`
- `auth/swarm_materialization_v0`
  - scope: `scenes/`
  - mutations: `PROPOSE` by default; direct materialization requires explicit temporary authority mint

No broad scopes (for example `scene/`, `scenes/`, `project/`) are allowed in swarm-specific tuples.

## Deterministic Control Loop (v0)

### Step 0: Preflight
- Read gate state from `scenes/kalshi_data_gate_v0.scene.json`.
- Validate scope exclusions and authority preconditions.
- Emit `scene/swarm/<run_id>/preflight_v0.json`.

### Step 1: Task intake
- Read task artifacts from canonical `scenes/` task sources.
- Apply deterministic selection function declared in manifest.
- Emit `scene/swarm/<run_id>/task_selection_v0.json`.

### Step 2: Sandbox allocation
- Allocate one isolated sandbox per specialist.
- Record allocations in `scene/sandbox/registry_v0.json`.
- Emit `scene/swarm/<run_id>/allocations_v0.json`.

### Step 3: Parallel specialist execution
- Fan out to fixed specialist set.
- Each specialist publishes outputs and refs to `scene/mailbox/messages_v0.jsonl`.
- Emit `scene/swarm/<run_id>/cycle_00N_outputs_v0.json`.

### Step 4: Review and merge proposal
- Reviewer validates scoped checks.
- Merger writes merge proposals to `scene/merge_queue/queue_v0.json`.
- Emit `scene/swarm/<run_id>/review_merge_v0.json`.

### Step 5: Materialization
- Convert accepted runtime outcomes into canonical `scenes/` artifacts.
- Emit `scene/swarm/<run_id>/materialization_v0.json`.

### Step 6: Final evaluation
- Emit `scene/audit_reports/v0/<run_id>_swarm_eval_v0.json` with:
  - scope compliance
  - blocked-scope mutation count
  - cross-namespace violations
  - required-artifact completeness
  - recommendation (`continue|adjust|stop`)

## Required Run Artifacts (minimum set)
- `scene/swarm/<run_id>/manifest_v0.json`
- `scene/swarm/<run_id>/preflight_v0.json`
- `scene/swarm/<run_id>/task_selection_v0.json`
- `scene/swarm/<run_id>/allocations_v0.json`
- `scene/swarm/<run_id>/cycle_001_outputs_v0.json`
- `scene/swarm/<run_id>/review_merge_v0.json`
- `scene/swarm/<run_id>/materialization_v0.json`
- `scene/audit_reports/v0/<run_id>_swarm_eval_v0.json`

## Out of Scope (v0)
- Nested swarms.
- Unbounded autonomous execution loops.
- Global gate creation or modification.
- Any override of `gate/kalshi_data_gate_v0` behavior.
- Branch-sync or protected-branch automation.

## Acceptance Criteria (v0)
- Run completes with zero blocked-scope mutations.
- Run completes with zero cross-namespace violations.
- Required run artifacts are present and machine-readable.
- Canonical outcomes exist only in `scenes/` after materialization.
- All behavior remains track-only until explicit promotion.
