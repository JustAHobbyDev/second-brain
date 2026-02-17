# Closeout Contract

Version: v0
Status: Legacy (deprecated default)
Inputs:
- `templates/session_template.json`
- `prompts/session_ending_prompt.md`
- `tools/sb_closeout.sh`

## Purpose
Define the legacy session-closeout contract for controlled migration/backfill runs.

Session tracking is deprecated by default in `project/second-brain`.
Primary audit surfaces are git history and `reports/checkpoints/*`.

## Required Top-Level Keys
- `artifact_id`
- `session_date`
- `llm_used`
- `project_links`
- `principle_links`
- `pattern_links`
- `tool_links`
- `related_artifact_links`
- `summary`
- `key_decisions`
- `open_questions`
- `next_steps`
- `thinking_trace_attachments`
- `prompt_lineage`
- `resumption_score`
- `resumption_notes`

## ID and Date Rules
- `artifact_id` format:
  - `artifact/{llm}_{YYYY_MM_DD}_{kebab-case-3-to-6-word-slug}`
- `llm_used` must match `artifact_id` prefix.
- `session_date` must be `YYYY-MM-DD` and match `artifact_id` date.

## Quality Gates (legacy runs only)
- `resumption_score` must be integer `0-10`.
- Passing closeout requires `resumption_score >= 6`.
- Default link density gates:
  - `project_links >= 1`
  - `principle_links >= 2`
  - `pattern_links >= 1`
- `open_questions` must be numbered and actionable (`1. ...`).
- `prompt_lineage` must include at least one object with `role` and `ref` or `summary`.

## Index Policy (legacy runs only)
- On successful closeout, auto-update `sessions/<tool>/index.json` by default.
- `--no-index` allowed only for controlled backfill/rollback/migration runs.

## Canonical Resolution
- Resolve project aliases via `scenes/project_id_alias_map.scene.json` when present.
- Prefer canonical scene IDs for projects/principles/patterns.

## Scene Fold Suggestion
- After successful closeout, suggest scene fold targets based on overlap with linked IDs.

## Reference Implementation
- `tools/sb_closeout.sh`
- Requires explicit `--legacy-session-write` opt-in.
