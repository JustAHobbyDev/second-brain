# Meta Workflow Execution Spec

Version: v0
Status: Experimental
Inputs:
- `operations/` operation specs
- `prompts/meta_program/` ordered prompt artifacts
- `scenes/*.scene.json` project scenes and histories
- `scenes/_schemas/*.schema.json` schema contracts
- `profiles/*.md` operating model templates

## Purpose
Define a deterministic, prompt-file workflow for Meta Program execution across EPIC A/B/C with schema-backed outputs and explicit governance controls.

## Scope (EPIC A/B/C)
- EPIC A: Generate deterministic project history artifacts.
- EPIC B: Define and apply phase model schemas for project phase history.
- EPIC C: Integrate closeout and cognitive operating-model templates into repo index/workflow.

## Architecture Overview
```text
prompts/meta_program/00_context.txt
        |
        v
prompts/meta_program/10_generate_project_history_spec.txt
        |
        v
operations/generate_project_history_v0.md
        |
        v
prompts/meta_program/20_phase_model_and_schema.txt
        |
        v
scenes/_schemas/phase_event_v0.schema.json
scenes/_schemas/phase_history_v0.schema.json
scenes/kalshi_phase_history.scene.json
        |
        v
prompts/meta_program/30_closeout_template_integration.txt
prompts/meta_program/40_cognitive_profile_spec.txt
        |
        v
profiles/dan_cognitive_operating_model_v0.md + README index links
```

## Cross-Epic Constraints
- Enforced order is A -> B -> C.
- EPIC B must consume the output contracts defined in EPIC A.
- EPIC C must not mutate EPIC A/B artifacts except by explicit version bump (`v0` -> `v1`, etc.).

## Determinism and Drift Tests
- Deterministic ordering rule for all generated lists: `content_timestamp` (ascending) -> metadata timestamp (ascending) -> filename lexical order (ascending).
- Deterministic serialization rule: UTF-8, 2-space indentation, stable key order in examples/docs.
- Drift test 1 (repeat-run): run the same prompt sequence twice with unchanged inputs; normalized artifact hashes must match.
- Drift test 2 (permutation): shuffle source file discovery order; resulting ordered outputs must remain identical.
- Drift test 3 (boundary): add one out-of-range artifact; output must remain unchanged when `date_range` excludes it.

## Governance Rules
- Versioning: new behavior requires new versioned files; no in-place semantic rewrites of prior versions.
- Spec naming convention for future additions: `<SCOPE>_<SUBJECT>_SPEC_vN.md` where `N` is monotonically increasing per subject (for example, `META_WORKFLOW_EXECUTION_SPEC_v1.md`, `PROJECT_HISTORY_SPEC_v1.md`).
- Schemas are mandatory contracts for scene history outputs.
- No silent mutations: any changed artifact must be observable in git diff and accompanied by updated links if path is new.
- Prompt files are executable governance documents; prompt order is normative.

## Failure Modes
- Non-deterministic ordering causes hash drift across repeat runs.
- Missing or invalid schema contracts blocks phase history generation.
- Untracked template dependencies cause partial closeout outputs.
- Unversioned edits to spec/template files create governance ambiguity.

## Success Criteria (v0)
- All EPIC A/B/C artifacts exist at required paths.
- Schemas are valid JSON Schema and phase history starter instance conforms.
- Driver script executes prompt files in order using `codex exec`.
- README index includes links to new meta artifacts.

## Immediate Next Step
Run the operation defined in `operations/generate_project_history_v0.md` and validate repeat-run stability before evolving to `v1`.
