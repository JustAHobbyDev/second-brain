Meta Program Prompt 10: Generate Project History Spec
Version: v0
Status: Experimental
Inputs:
- `meta/META_PROGRAM_SPEC_v0.md`
- Repository artifact folders used for history extraction

Task:
Create or update `operations/generate_project_history_v0.md` with:
- Operation signature: `generate_project_history(scene_id, date_range?, abstraction_level?)`
- Included/excluded folders and artifact classes
- Temporal precedence rule: content timestamp > metadata > filename
- Output fields: milestones[], inflection_points[], governance_events[], risk_flags[], trajectory_summary
- Determinism guarantees and explicit drift tests (repeat-run stability required)
- Failure modes and Definition of Done checklist
- Small realistic JSON output example

Guardrails:
- Version and status must remain `v0` / `Experimental`.
- Keep wording implementation-ready and deterministic.
