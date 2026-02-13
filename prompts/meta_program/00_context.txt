Meta Program Context Prompt
Version: v0
Status: Experimental
Inputs:
- Repository root structure and existing conventions
- `meta/`, `operations/`, `scenes/`, `profiles/`, `templates/`, `README.md`

Global constraints:
- Make minimal, additive edits.
- Prefer creating versioned files over mutating existing files.
- Every new spec/template must include Version, Status, Inputs.
- Determinism is mandatory: define ordering and drift tests.
- No silent mutations; all behavior/documentation changes must be visible in git diff.
- Use internal RFC tone; no motivational framing.

Execution context:
- Implement EPIC A/B/C in strict order.
- Keep schema and template artifacts versioned (`v0`).
- If a required template is missing, create a minimal versioned template instead of skipping.
