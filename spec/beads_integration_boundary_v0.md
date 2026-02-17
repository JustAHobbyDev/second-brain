# Beads Integration Boundary v0

Version: v0
Status: Draft
Scope: project/dan_personal_cognitive_infrastructure
Enforcement default: Level 2 (track-only)

## Purpose
Define a strict, low-entropy boundary for evaluating Beads as a runtime orchestration layer without violating canonical second-brain architecture.

This spec is integration policy, not a replacement architecture.

## Invariant Linkage (existing canonical IDs)
- inv/scenes_source_of_truth
- inv/agents_resume_cold
- inv/derived_view_integrity
- inv/reduce_entropy_never_increase
- inv/scoped_constraints_preferred

## Core Boundary Invariants (v0)
- `inv/beads_boundary_01`: Beads runtime state is operational only and must never be treated as canonical truth.
- `inv/beads_boundary_02`: Canonical decisions and knowledge must land in `scenes/` with stable IDs.
- `inv/beads_boundary_03`: Every accepted Beads-driven mutation must be attributable via `scene/ledger/*`.
- `inv/beads_boundary_04`: Beads integration must remain scoped to declared pilot paths; no global gate behavior.
- `inv/beads_boundary_05`: Integration must not mutate blocked Kalshi pipeline scope while gate is active.
- `inv/beads_boundary_06`: Branch-sync/protected-branch automation is disabled during pilot.
- `inv/beads_boundary_07`: Promotion is allowed only after deterministic pilot pass criteria are met.

## Integration Boundary (normative)

### Allowed runtime paths
- `scene/beads/`
- `state/beads/`
- `scene/audit_reports/v0/` (pilot reports only)
- `scene/ledger/mutations_v0.jsonl` (attribution records)

### Allowed canonical path
- `scenes/` only for finalized decision materialization artifacts.

### Disallowed paths (pilot hard rule)
- Any direct Beads-managed write into `project/kalshi_15m_btc_pipeline`.
- Any direct Beads-managed write into `scenes/kalshi_15m_btc_pipeline.scene.json`.
- Any global gate modification.

## Tool Contract Requirements
Any helper tool introduced for Beads pilot must declare:

1. `TARGET_NAMESPACE` = `scene` or `mixed`
2. `ALLOWED_PATH_PREFIXES` as explicit list
3. `BOUNDARY_JUSTIFICATION` when `TARGET_NAMESPACE=mixed`

If omitted, the tool is invalid under this spec.

## Authority Registry Churn Guardrail (track-only)
This guardrail applies to Beads-scoped authority tuples only (prospective rule):

- Applies when either condition is true:
  - `authority_id` starts with `auth/beads_`, or
  - tuple scope includes `scene/beads/` or `state/beads/`.
- Scope entries must be repo-root-relative path prefixes.
- Wildcards are disallowed in Beads-scoped tuple scope (`*` forbidden).
- Broad scopes are disallowed in Beads-scoped tuple scope:
  - `scene/`
  - `state/`
  - `scenes/`
  - `project/`
- Tuple-per-surface discipline:
  - one mutable runtime surface per tuple (for example one of `scene/beads/` or `state/beads/`, not both).

Enforcement mode remains track-only in v0; violations must be emitted as audit findings.

## Authority Constraints (pilot)
- Default operator: `agent/orchestrator_v0` in track-only mode.
- Optional contributors: domain maintainers in scoped `PROPOSE` mode only unless temporary execution tuple is explicitly minted.
- PM remains delegator/planner by default.
- All pilot mutations require:
  - mutation record append in `scene/ledger/mutations_v0.jsonl`
  - corresponding cursor update for acting agent

## Deterministic Pilot Checklist (v0)

### Run ID rule
- `run_id = beads_pilot_<YYYYMMDD>_v0`
- All pilot artifacts must include this exact `run_id`.
- Use template `templates/beads_pilot_run_template_v0.json` to keep field shape deterministic.

### Step 0: Preflight boundary check
- Confirm Kalshi gate status is read from `scenes/kalshi_data_gate_v0.scene.json`.
- Confirm pilot scope excludes Kalshi pipeline paths.
- Emit `scene/audit_reports/v0/<run_id>_preflight_v0.json`.

Pass condition:
- `gate_scope_excluded == true`
- `blocked_scope_targets_detected == 0`

### Step 1: Baseline snapshot
- Capture current coordination baseline (claims, queue size, warning counts, unresolved proposals).
- Emit `scene/audit_reports/v0/<run_id>_baseline_v0.json`.

Pass condition:
- Baseline report exists with numeric fields for all tracked metrics.

### Step 2: Runtime sandbox declaration
- Register pilot runtime scope under `scene/beads/<run_id>/manifest_v0.json`.
- Include: scope prefixes, acting agents, and explicit "runtime_only": true.

Pass condition:
- Manifest exists and all scope prefixes are under allowed runtime paths.

### Step 3: Deterministic task selection
- Select exactly 3 tasks from `scene/task_queue/v0.json` using this rule:
  1) `status in ["queued", "proposed"]`
  2) excludes any Kalshi pipeline scope
  3) ascending lexical `task_id`
  4) take first 3
- Emit `scene/beads/<run_id>/task_selection_v0.json`.

Pass condition:
- `selected_count == 3`
- `kalshi_scope_selected == 0`

### Step 4: Shadow execution cycles
- Run 3 pilot cycles (one per selected task) using Beads for coordination only.
- For each cycle emit:
  - `scene/beads/<run_id>/cycle_00N_log_v0.json`
  - `scene/audit_reports/v0/<run_id>_cycle_00N_eval_v0.json`

Pass condition (per cycle):
- `attribution_complete == true`
- `cross_namespace_violation == false`
- `blocked_scope_mutation == false`

### Step 5: Canonical materialization
- For each accepted decision, write a canonical artifact in `scenes/` with refs back to pilot cycle logs.
- Emit `scene/audit_reports/v0/<run_id>_materialization_v0.json`.
- Run `python3 scripts/run_beads_boundary_audit.py` and retain report output for disposition.

Pass condition:
- `decision_materialization_coverage == 100`
- `materialization_violations == 0` in beads boundary audit output.

### Step 6: Final evaluation and disposition
- Emit `scene/audit_reports/v0/<run_id>_final_eval_v0.json` with:
  - invariant violation counts
  - cross-namespace violations
  - blocked scope mutations
  - materialization violations
  - completed cycles
  - coordination overhead delta
  - recommendation (`promote|extend_pilot|reject`)

Promotion criteria:
- `invariant_violations == 0`
- `cross_namespace_violations == 0`
- `blocked_scope_mutations == 0`
- `completed_cycles == 3`
- `decision_materialization_coverage == 100`
- `coordination_overhead_reduction_pct >= 20` or `insufficient_data == true`

## Failure Handling
- Any invariant breach forces disposition `reject` for current run.
- Any missing required artifact forces disposition `extend_pilot`.
- No automatic gate escalation is allowed in v0.

## Out of Scope (v0)
- Replacing existing canonical `scenes/` model.
- Global workflow migration to Beads.
- Branch-sync mode enablement.
- Any non-scoped hard gate introduction.

## Activation Rule
Remain draft and track-only until:

1. At least one full pilot run passes all non-optional criteria.
2. Human review approves promotion in a consultation artifact.
3. Authority registry is explicitly updated for any expanded mutation rights.
