# Generate Project History Operation

Version: v0
Status: Experimental
Inputs:
- Included folders: `reports/checkpoints/`, `scenes/`, `prompts/`, `operations/`, `meta/`, `profiles/`, `templates/`, `tools/` (`sessions/` optional legacy)
- Excluded folders: `.git/`, `graph/` (optional export cache), transient temp files
- Artifact classes: checkpoint artifacts, scene artifacts, operation specs, governance docs, templates (session artifacts = legacy)

## Operation Signature
`generate_project_history(scene_id, date_range?, abstraction_level?)`

## Parameters
- `scene_id` (required, string): canonical project/scene identifier.
- `date_range` (optional, object): `{ "start": "YYYY-MM-DD", "end": "YYYY-MM-DD" }`.
- `abstraction_level` (optional, enum): `"low" | "medium" | "high"` (default `"medium"`).

## Input Resolution Rules
- Inclusion priority is deterministic and path-based.
- Temporal ordering precedence is strict: content timestamp > metadata timestamp > filename timestamp token.
- If timestamps tie, apply lexical order on normalized relative path.
- If an artifact has no parseable timestamp, treat timestamp as null and sort after timestamped artifacts using lexical path.

## Output Contract
Output is a JSON object with fields:
- `milestones[]`
- `inflection_points[]`
- `governance_events[]`
- `risk_flags[]`
- `trajectory_summary`

### Field Shape (v0)
- `milestones[]`: `{ "date": "YYYY-MM-DD", "title": "...", "evidence": ["path"] }`
- `inflection_points[]`: `{ "date": "YYYY-MM-DD", "change": "...", "confidence": 0.0-1.0 }`
- `governance_events[]`: `{ "date": "YYYY-MM-DD", "decision": "...", "artifact": "path" }`
- `risk_flags[]`: `{ "type": "regression|oscillation|stagnation|dependency", "severity": "low|medium|high", "note": "..." }`
- `trajectory_summary`: short deterministic narrative derived from ordered evidence.

## Determinism Guarantees
- Stable discovery: sort candidate files lexically before parsing.
- Stable event ranking: apply precedence rule (`content` > `metadata` > `filename`) with deterministic tie-breaks.
- Stable rendering: JSON serialized with consistent spacing and key order.
- Stable abstraction mapping: identical `abstraction_level` must produce identical output given unchanged inputs.

## Drift Tests
- Repeat-run stability: run operation twice without repo changes; byte-identical outputs required.
- Discovery-order invariance: randomize input enumeration order; output must remain byte-identical.
- Date-window invariance: widening date range must only append in-range events, not reorder existing events.
- Null-timestamp behavior: artifacts lacking timestamps must remain deterministically ordered by path.

## Failure Modes
- Ambiguous timestamp extraction from content and metadata.
- Missing `scene_id` or unresolved scene mapping.
- Schema drift in downstream consumers expecting different field names.
- Non-deterministic parser behavior from unordered map iteration.

## Definition of Done
- [ ] Operation signature is implemented or callable in workflow context.
- [ ] Output contains all required top-level fields.
- [ ] Determinism guarantees and drift tests pass on repeat runs.
- [ ] Failure cases emit explicit error messages with failing artifact paths.
- [ ] Result is linked from meta index/readme.

## Example Output JSON
```json
{
  "milestones": [
    {
      "date": "2026-02-11",
      "title": "Phase8 closeout handoff captured",
      "evidence": ["sessions/codex/2026-02-12-phase8-closeout-handoff.json"]
    }
  ],
  "inflection_points": [
    {
      "date": "2026-02-12",
      "change": "Shift from ad-hoc prompts to versioned operation specs",
      "confidence": 0.82
    }
  ],
  "governance_events": [
    {
      "date": "2026-02-13",
      "decision": "Adopt EPIC A/B/C ordered meta workflow",
      "artifact": "meta/META_PROGRAM_SPEC_v0.md"
    }
  ],
  "risk_flags": [
    {
      "type": "oscillation",
      "severity": "medium",
      "note": "Prompt conventions changed multiple times in two days"
    }
  ],
  "trajectory_summary": "Project is converging on schema-governed, deterministic workflow artifacts with moderate process churn risk."
}
```
