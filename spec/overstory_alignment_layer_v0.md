# Overstory Alignment Layer v0

Version: v0
Status: Draft
Scope: project/dan_personal_cognitive_infrastructure
Enforcement default: Level 2 (track-only)

## Purpose
Adapt selected Overstory coordination patterns into `project/second-brain` without violating:

- inv/scenes_source_of_truth
- inv/agents_resume_cold
- inv/reduce_entropy_never_increase
- inv/scoped_constraints_preferred

This alignment layer maps practical orchestration moves into the current model:

- `scenes/` = canonical truth artifacts
- `scene/` = runtime state surfaces
- Authority = mutation rights (MAAM v0)

## Scope
Included (adapted):
1. Typed agent messaging
2. Workspace isolation via sandboxes (worktrees optional)
3. Merge and acceptance flow as scoped gates
4. Monitoring and escalation as non-mutating audit/reporting

Excluded:
- Global hierarchies and implicit authority
- Any design that makes runtime state canonical truth
- Any gate that blocks outside its declared scope

## Core Invariants
- inv/over_align_01 Messages are runtime coordination, never canonical truth.
- inv/over_align_02 Canonical decisions and knowledge must land in `scenes/`, not `scene/`.
- inv/over_align_03 Every mutation must be attributable via `scene/ledger/*`.
- inv/over_align_04 Workspace isolation is a scoped constraint, not a governance system.
- inv/over_align_05 Conflict resolution must be expressed as authority plus gates, not role power.

## 1) Roles to Authority Bundles (no hierarchy)
Overstory-style roles are represented as capability bundles, not titles:

- bundle/orchestrate_v0
- bundle/scout_v0
- bundle/build_v0
- bundle/review_v0
- bundle/merge_v0
- bundle/monitor_v0

Bundle definitions and bundle-level tuples are represented in `scene/authority/registry_v0.json`.

Rule: Bundles grant only necessary mutation rights. Any broader rights require explicit scoped authority tuples.

## 2) Messaging to Runtime Mailbox (typed, durable, non-canonical)
Canonical runtime surfaces:

- scene/mailbox/messages_v0.jsonl (append-only runtime coordination stream)
- scene/mailbox/index_v0.json (optional derived index)

Canonical decisions derived from messages must be written to `scenes/...` and referenced by pointer.

### Message schema v0 (normative)
`scene/mailbox/messages_v0.jsonl` record fields:

- msg_id
- ts
- from_agent
- to (agent_id or group tag)
- type (enum)
- refs (list of `scene/` or `scenes/` pointers)
- body (short runtime text)
- requires_ack (bool)
- status (`sent|acked|closed`)

### Message types (minimal)
- TASK_ASSIGN
- DISCOVERY_REPORT
- BUILD_PROPOSAL
- REVIEW_FINDINGS
- MERGE_REQUEST
- ESCALATION
- GATE_STATUS
- HEALTH_ALERT

## 3) Workspace Isolation to Sandbox Pattern (worktree optional)
A sandbox is a scoped execution surface tied to authority, not authority itself.

Runtime surface:
- scene/sandbox/registry_v0.json

Sandbox record fields:
- sandbox_id
- agent_id
- repo_ref (optional)
- path (optional)
- scope_grant (authority_id)
- created_at
- expires_at (optional)
- notes

Rule: Sandbox existence never grants mutation rights. It only references an authority grant.

## 4) Merge Flow to Scoped Gate plus Merge Queue
Runtime surfaces:
- scene/merge_queue/queue_v0.json
- scoped merge gate scene under `scenes/` (project-specific)

### Merge queue item schema (normative)
- merge_id
- proposed_by
- target_scope (path prefix list)
- inputs (refs to scenes and artifacts)
- diff_ref (change pointer)
- required_reviews (count or named agents)
- gate_checks (list)
- status (`queued|reviewing|blocked|merged|rejected`)
- resolution_note_ref (must point to `scenes/...` when merged)

### Gate checks (minimal)
- terminology pass (when applicable)
- invariant drift pass (when applicable)
- scoped hard gates respected (for example Kalshi data gate)
- no cross-namespace violation (`scenes/` truth not written into `scene/`)

Invariant: Merge is permitted only when scoped merge checks pass and resolution note lands in `scenes/`.

## 5) Monitoring and Escalation to Non-Mutating Health Layer
Runtime surfaces:
- scene/health/heartbeat_v0.jsonl
- scene/health/alerts_v0.jsonl
- scene/audit_reports/*

Rule: Monitors never directly mutate canonical truth. They may report, escalate, propose, and trigger scoped blocks only if explicitly authorized.

## 6) Compatibility with Current State (low entropy)
Immediate runtime-only surfaces introduced in this v0:

- scene/mailbox/messages_v0.jsonl
- scene/merge_queue/queue_v0.json
- scene/sandbox/registry_v0.json
- scene/health/alerts_v0.jsonl

No new global gate is introduced.
Existing scoped gates remain unchanged.

## Minimal Adoption Plan
1. Adopt typed mailbox for agent coordination (`scene/mailbox/*`)
2. Adopt merge queue for multi-agent changes (`scene/merge_queue/*`)
3. Adopt sandbox registry for tool-agnostic isolation (`scene/sandbox/*`)

Stop after these three steps in v0.

## Open Questions
- Should `scene/mailbox/*` remain durable append-only runtime records indefinitely, or rotate with archival policy?
- Should merge authority remain centralized to bundle/merge_v0, or allow in-scope maintainer merges by domain?

