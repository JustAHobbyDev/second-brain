# Prompt Lineage Ontology Spec

Version: v0
Status: Experimental
Inputs:
- `prompts/` base prompt artifacts
- `scenes/*.scene.json` ontology and workflow scenes
- `meta/*.md` governance and ontology specs
- `operations/*.md` prompt generation and integration operations
- `meta/ONTOLOGY_ARCHITECTURE_MAP_v0.md` layered semantic context

## Purpose
Define canonical ontology entities and relations for representing prompt evolution from reusable base templates to context-specific concretions.

## Scope
- In scope:
  - Prompt lineage modeling (`base -> delta -> materialized`)
  - Deterministic lineage replay
  - Queryable provenance for prompt derivations
- Out of scope:
  - LLM quality evaluation of prompt effectiveness
  - Automatic semantic merging of conflicting deltas

## Layer Placement
- This spec primarily inhabits **Layer L3 (Ontology)** from `meta/ONTOLOGY_ARCHITECTURE_MAP_v0.md`.
- Serialization rules referenced here must defer to L4 schemas (e.g., prompt lineage artifact schemas) and cite them explicitly when required.
- Governance references (L1) such as “no in-place mutation” inherit from `SPEC_SPEC_v0` and related governance specs; changes that alter governance intent must be codified there first.

## Core Entities
- `PromptArtifact`
  - Canonical prompt content unit (base or materialized).
  - Required fields: `id`, `type`, `title`, `content`, `version`, `status`.
- `PromptDelta`
  - Incremental transformation over a base prompt.
  - Required fields: `id`, `delta_type`, `patch`, `order`, `version`, `status`.
- `PromptVariant`
  - Named target variant (for tool/context/domain specialization).
  - Required fields: `id`, `target_context`, `version`, `status`.
- `PromptMaterializationRun`
  - Deterministic replay execution record.
  - Required fields: `id`, `base_prompt_id`, `applied_delta_ids[]`, `output_prompt_id`, `generated_on`.

## Relations
- `expands` (`PromptDelta -> PromptArtifact`)
- `concretizes` (`PromptDelta -> PromptVariant`)
- `derived_from` (`PromptArtifact -> PromptArtifact`)
- `materialized_by` (`PromptArtifact -> PromptMaterializationRun`)
- `applies_delta` (`PromptMaterializationRun -> PromptDelta`)
- `targets_context` (`PromptVariant -> concept/*`)
- `supersedes` (`PromptArtifact|PromptDelta -> PromptArtifact|PromptDelta`)

## Identity and Naming
- Prompt IDs should be stable and semantic: `prompt/<domain>_<purpose>_vN`.
- Delta IDs should encode order and intent: `prompt_delta/<base>_<order>_<intent>_vN`.
- Materialized prompt IDs should include variant key: `prompt/<base>__<variant>_vN`.

## Deterministic Materialization Rules
- Delta application order: ascending numeric `order`; tie-break by delta `id` lexical order.
- Base selection: exact `base_prompt_id` match; no fuzzy fallback.
- Patch execution rule: apply operations in listed order; unsupported operation fails closed.
- Output serialization: UTF-8, two-space indentation, stable key ordering for structured outputs.

## Drift Tests
- Repeat-run stability: same base + same ordered deltas must produce byte-identical output.
- Permutation invariance: shuffled input delta discovery must still resolve to identical ordered application.
- Supersession stability: when a delta is superseded, active set resolution must be deterministic.
- Missing-delta failure: referenced but missing delta IDs must fail without partial output.

## Governance Rules
- Lineage is explicit, not inferred: all derivations must use `derived_from` and `materialized_by` links.
- No in-place semantic mutation of historical prompts; create a new versioned artifact instead.
- Every materialized output must retain replay metadata (`base_prompt_id`, `applied_delta_ids`).
- Changes to ontology semantics require version bump (`v0` -> `v1`).

## Failure Modes
- Delta order ambiguity (`order` missing or duplicate without deterministic tie-break).
- Circular `derived_from` chains.
- Missing base artifact for materialization run.
- Conflicting deltas that modify identical span without conflict policy.

## Success Criteria (v0)
- A coding agent can reconstruct a materialized prompt from base + deltas deterministically.
- Prompt lineage is queryable from artifacts and relations without heuristic inference.
- Drift tests pass for repeat-run and permutation scenarios.

## Immediate Next Step
Define a minimal prompt-delta artifact schema and add one lineage example for `prompts/session_archiver_prompt_template.md`.
