# Multi-Agent Mutation Authority Model v0

Version: v0
Status: Draft
Scope: project/dan_personal_cognitive_infrastructure
Enforcement default: Level 2 (track-only)

## Purpose
Define a minimal, scene-grounded authority model for multiple agents that:
- preserves inv/scenes_source_of_truth
- preserves inv/agents_resume_cold
- reduces entropy via scoped mutation rights
- avoids importing human hierarchy by default

## Core Invariants
- inv/maamv0_01 Authority is mutation rights.
- inv/maamv0_02 Scenes are the only mutable source-of-truth.
- inv/maamv0_03 All mutations must be attributable (agent ID + reason + inputs).
- inv/maamv0_04 Authority is scoped by artifact path + operation type.
- inv/maamv0_05 No global gates; only scoped gates.
- inv/maamv0_06 Cold resume requires reconstructing authority from scenes.

## Canonical Linkage (existing repo invariants)
- inv/scenes_source_of_truth aligns with inv/derived_view_integrity.
- inv/agents_resume_cold aligns with inv/agent_resumption_min_8.

## Definitions

### Artifact Classes
- scene/ - mutable, source of truth.
- spec/ - versioned, immutable once activated (new version required for changes).
- inv/ - invariant registry (append-only; deprecations allowed but never deletion).
- project/ - plan/roadmap artifacts (mutable only via governed process).
- gate/ - scoped hard gates (must declare scope + blocking behavior).

### Mutation Types
- CREATE
- UPDATE
- ARCHIVE (soft removal; must preserve referential integrity)
- DEPRECATE (for inv/ and spec/ references; never delete)
- PROPOSE (non-mutating suggestion packaged for review)
- ACTIVATE (promote spec/*_vN to active)
- BLOCK / UNBLOCK (gate state changes; scoped only)

## Authority Model
Authority is a tuple:
(subject_agent, artifact_scope, mutation_type, conditions)

Represented canonically as a scene artifact:
- scene/authority/registry_v0.json

### Minimal Schema (normative)
- authority_id (stable)
- agent_id
- scope (path prefix or explicit list)
- allowed_mutations (list)
- conditions (list of named checks)
- issued_by (agent_id)
- issued_at (timestamp)
- expires_at (optional; prefer no expiry unless necessary)
- revocation (optional block)

## Roles as Bundles (Not Titles)
Roles are optional convenience bundles of authority tuples:
- role/orchestrator_v0
- role/specialist_<domain>_v0
- role/auditor_v0
- role/maintainer_<artifact_group>_v0

Role assignment is just applying a pre-defined set of authority tuples.
No implied hierarchy.

## Required Agents (minimum viable multi-agent)

### 1) agent/orchestrator_v0
Purpose: routing + conflict resolution + ensuring scoped constraints.

Authority:
- UPDATE on scene/task_queue/*
- UPDATE on scene/authority/*
- PROPOSE on project/* and spec/* (no direct activation by default)

### 2) agent/maintainer_<domain>_v0
Purpose: mutate within a domain's scenes and maintain produced artifacts.

Authority:
- CREATE/UPDATE/ARCHIVE within scene/<domain>/*
- PROPOSE updates elsewhere

### 3) agent/auditor_v0
Purpose: verify invariants + detect drift, no mutation except reporting.

Authority:
- CREATE on scene/audit_reports/*
- PROPOSE only elsewhere

## Mutation Protocol v0 (deterministic)
Every mutation must produce:
1. A mutation record appended to scene/ledger/mutations_v0.jsonl
2. A checkpoint cursor update to scene/agent/<agent_id>/cursor_v0.json

### Mutation Record Fields (minimum)
- mutation_id
- timestamp
- agent_id
- target_path
- mutation_type
- inputs (scene IDs)
- reason (short)
- pre_hash / post_hash (if applicable)
- gate_status (if any gate scoped to target)

This enforces cold resume.

## Conflict Resolution v0
A conflict is defined as:
- two agents proposing incompatible mutations to the same scope, or
- a mutation violating a gate/invariant.

Resolution rule:
- Orchestrator does not decide by hierarchy.
- Orchestrator routes to the appropriate scope owner (maintainer) and requires:
  - a single accepted mutation proposal
  - an audit note if invariants were at risk
- If no scope owner exists, orchestrator can mint a temporary authority tuple with explicit expiry and justification.

## Scoped Gates Integration
A gate must declare:
- gate_id
- scope (path prefixes)
- block_condition (machine-checkable where possible)
- blocked_effect (what is prevented)
- exclusions (what is not blocked)

Rule:
- Gates may only block mutations within their scope.

Example alignment:
- gate/kalshi_data_gate_v0 blocks project/kalshi_15m_btc outputs only.

## Activation and Change Control

### Specs
- spec/*_v0 becomes active only via ACTIVATE authority.
- Default: only agent/orchestrator_v0 can ACTIVATE.
- Activation requires:
  - audit pass (scene/audit_reports/...)
  - invariant mapping update (if new invariants introduced)

### Invariants
- inv/ is append-only.
- Drift triggers produce scene/audit_reports/*.
- Fixes are handled as spec updates, not silent rule edits.

## Minimal Deliverables (v0 implementation set)
- scene/authority/registry_v0.json
- scene/ledger/mutations_v0.jsonl
- scene/task_queue/v0.json
- scene/audit_reports/v0/ (folder convention)
- scene/agent/orchestrator/cursor_v0.json
- scene/agent/auditor/cursor_v0.json

## Success Criteria
- Any agent can resume from cold using only scene artifacts listed above.
- No agent can mutate outside its scoped authority.
- All mutations are attributable and reconstructable.
- Adding agents increases throughput without increasing global coupling.

## Open Questions
- Do we want authority tuples to be time-bounded by default, or permanent until revoked?
- Do we require pre_hash/post_hash for all mutations or only for non-append-only files?
