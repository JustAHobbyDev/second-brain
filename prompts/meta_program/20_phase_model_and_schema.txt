Meta Program Prompt 20: Phase Model and Schema
Version: v0
Status: Experimental
Inputs:
- `operations/generate_project_history_v0.md`
- Existing scene naming conventions in `scenes/`

Task:
Create:
- `scenes/_schemas/phase_event_v0.schema.json`
- `scenes/_schemas/phase_history_v0.schema.json`
- `scenes/kalshi_phase_history.scene.json` starter instance

Requirements:
- Use valid JSON Schema (draft-07+).
- `phase_event` must define: phase enum, entered_on (ISO date), trigger_artifact, confidence_score (0..1), optional notes.
- `phase_history` must define: schema_version, project_id, phase_events[], drift_signals, generated_on.
- Use `$ref` to phase_event schema when feasible.
- Starter instance must include 2-3 plausible events and deterministic field ordering.
- Include deterministic ordering and drift signal semantics in schema descriptions.
