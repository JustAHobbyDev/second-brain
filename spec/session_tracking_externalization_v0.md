# Session Tracking Externalization v0

Version: v0
Status: Draft
Scope: project/dan_personal_cognitive_infrastructure
Enforcement default: Level 2 (track-only)

## Purpose
Reclassify in-repo session tracking as legacy and keep second-brain focused on epistemic infrastructure.

## Policy Decisions (v0)

1. Session writes under `sessions/` are deprecated by default.
2. Primary provenance/audit surfaces in this repo are:
   - git history
   - `reports/checkpoints/*`
3. Canonical ingestion rule:
   - ingest only canonical outcomes into `scenes/`,
   - each outcome must include stable canonical ID and source refs.
4. `sessions/*` remains historical/legacy storage only.

## Invariant Linkage
- inv/scenes_source_of_truth
- inv/derived_view_integrity
- inv/reduce_entropy_never_increase
- inv/scoped_constraints_preferred

## Canonical Outcome Requirement
Any new canonical outcome written to `scenes/` must include:

- stable `type/id` reference(s),
- source evidence reference(s) (commit hash and/or checkpoint report path and/or immutable report artifact),
- concise decision rationale.

If source references are missing, artifact status must be advisory, not canonical.

## Legacy Controls
- `tools/sb_closeout.sh` requires explicit `--legacy-session-write`.
- `tools/sb.py commit-session` requires explicit `--legacy-session-write`.

These controls prevent accidental new session sprawl in `sessions/`.

## Open Question Linkage
See `OPEN_QUESTIONS.md`:
- OQ-5 (whether second-brain should ingest any external session-tracker data at all).
