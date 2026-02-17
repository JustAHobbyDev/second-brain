# Scene Namespace Boundary v0

Version: v0
Status: Draft
Scope: project/dan_personal_cognitive_infrastructure
Enforcement default: Level 2 (track-only) until explicitly activated

## Purpose
Codify and protect the dual-layer scene model:

- `scenes/` = canonical epistemic source of truth
- `scene/` = runtime execution state namespace

This boundary prevents namespace drift, preserves cold resume guarantees, and keeps mutability semantics explicit.

## Invariant Linkage
- inv/scenes_source_of_truth
- inv/agents_resume_cold
- inv/derived_view_integrity

## Core Boundary Invariants (v0)

- `inv/scene_ns_01`  
  Only `scenes/` may contain canonical scene artifacts.

- `inv/scene_ns_02`  
  Only `scene/` may contain runtime execution state.

- `inv/scene_ns_03`  
  Runtime artifacts under `scene/` must be either:
  - ledger-durable operational records, or
  - reconstructable projections from `scenes/` plus logs.

- `inv/scene_ns_04`  
  No artifact may migrate between `scenes/` and `scene/` without version bump and deprecation record.

## Dual-Layer Model (normative)

### `scenes/` (Epistemic Truth Layer)
- Durable, version-controlled, human-legible knowledge artifacts.
- Stable references for system understanding and cold-resume grounding.
- Source-of-truth semantic state.

### `scene/` (Execution State Layer)
- Operational state surfaces for agent execution.
- Authority, coordination, mutation history, cursors, and runtime projections.
- Not a second epistemic truth layer.

## Durability Classes (explicit)

### Class A: Canonical Durable (epistemic)
- Namespace: `scenes/`
- Role: semantic/system truth
- Rebuild policy: not derived from runtime; maintained directly as canonical artifacts
- Examples:
  - `scenes/*.scene.json`
  - `scenes/_schemas/*.json`

### Class B: Operational Durable (ledger-backed runtime record)
- Namespace: `scene/` (and approved coordination record surfaces)
- Role: replay-critical execution record
- Rebuild policy: should survive restarts; used for deterministic replay and attribution
- Examples:
  - `scene/ledger/mutations_v0.jsonl`
  - `scene/authority/registry_v0.json`
  - `coord_claims.md`

### Class C: Reconstructable Runtime (projection state)
- Namespace: `scene/` and `state/`
- Role: current operational snapshot for convenience and fast continuation
- Rebuild policy: reconstructable from Class A + Class B
- Examples:
  - `scene/agent/*/cursor_v0.json`
  - `scene/agent/*/status_v0.json`
  - `scene/task_queue/v0.json`
  - `state/*.json`

### Class D: Derived Reports (advisory outputs)
- Namespace: `reports/` and `scene/audit_reports/`
- Role: analysis outputs and diagnostics
- Rebuild policy: recomputable from source inputs
- Examples:
  - `reports/*.json`
  - `scene/audit_reports/v0/*.json`

## Allowed Namespace Mapping (v0)

- Canonical scene/domain model artifacts: `scenes/` only.
- Runtime authority/cursor/ledger state: `scene/` only.
- Derived graph exports: `graph/` only (derived, never canonical source).
- Any violation is boundary drift and must be remediated as an invariant issue.

## External Evidence Ingestion Rule (v0)

Second-brain is infrastructure, not a raw session log sink.

- Do not ingest raw chat/session transcripts as canonical artifacts.
- Ingest only canonical outcomes into `scenes/`, with:
  - stable canonical ID,
  - explicit source references (for example commit hash, checkpoint report path, or immutable report artifact),
  - short decision rationale.
- If source references are missing, outcome is advisory only and must not be treated as canonical truth.

## Tool Requirements (normative contract)

All repository tools that mutate tracked files must declare namespace intent.

### Required Declarations

Every mutating tool under `tools/` or `scripts/` must include:

1) `TARGET_NAMESPACE` with one of:
- `scenes`
- `scene`
- `mixed` (only when strictly necessary and justified)

2) `ALLOWED_PATH_PREFIXES` as explicit writable prefixes.

3) `BOUNDARY_JUSTIFICATION` when `TARGET_NAMESPACE=mixed`.

If `TARGET_NAMESPACE` is omitted, the tool is invalid under this spec.

### Write Rules

- `TARGET_NAMESPACE=scenes`:
  - may write only `scenes/` (and allowed metadata outputs explicitly listed).
- `TARGET_NAMESPACE=scene`:
  - may write only `scene/` runtime surfaces (plus approved runtime companions like `state/`).
- `TARGET_NAMESPACE=mixed`:
  - requires explicit boundary justification and audit note.
  - should be rare and temporary.

## Migration Rule (inv/scene_ns_04 protocol)

When moving an artifact between namespaces:

1. Create new versioned artifact at destination namespace.
2. Mark prior artifact deprecated (do not silently overwrite lineage).
3. Record migration rationale in changelog/task/audit artifact.
4. Update references to the new canonical location.
5. Preserve replay continuity for runtime records.

No silent in-place namespace moves are allowed.

## Cold Resume Algorithm (clarified)

1. Load canonical state from `scenes/`.
2. Reconstruct active authority model.
3. Replay mutation history from `scene/ledger/*`.
4. Restore agent cursors/status from runtime projections.
5. Validate namespace invariants (`inv/scene_ns_*`, `inv/scenes_source_of_truth`, `inv/agents_resume_cold`).

## Validation and Audit Expectations (v0)

- Validation mode: track-only by default.
- Recurring audit should detect:
  - cross-namespace write drift,
  - missing `TARGET_NAMESPACE`,
  - invalid path-prefix declarations,
  - untracked namespace migrations.
- Violations produce audit findings and remediation proposals; no auto-mutation.

## Acceptance Criteria (Draft)

- Boundary model and durability classes are explicit and unambiguous.
- `scenes/` vs `scene/` semantics are machine-checkable by path rules.
- Tool declaration requirements are defined for enforceable audits.
- Cold-resume flow is deterministic and namespace-aware.
