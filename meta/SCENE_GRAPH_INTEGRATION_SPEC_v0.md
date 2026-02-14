# Scene Graph Integration Spec

Version: v0
Status: Experimental
Inputs:
- `scenes/*.scene.json` source scene artifacts
- `scenes/_schemas/*.schema.json` scene and graph schema contracts
- `graph/graph.json` optional derived graph export
- `operations/incorporate_scene_into_graph_v0.md` executable operation contract

## Purpose
Define deterministic incorporation of scene artifacts into an optional derived graph export so heterogeneous scene formats can be queried without replacing scene-level source truth.

## Scope
- In scope:
  - Graph-native scenes (`nodes[]`, `edges[]`)
  - Phase-history scenes (`schema_version`, `project_id`, `phase_events[]`, `drift_signals`, `generated_on`)
  - Custom object scenes (`id`, `type`, plus optional `relations[]`)
  - Document scenes (object scenes without graph arrays, normalized via `id`/`artifact`/filename fallback)
- Out of scope:
  - Destructive graph rewrites
  - Cross-repo graph federation
  - Automatic ontology inference beyond explicit scene fields

## Architecture
```text
scenes/*.scene.json
      |
      v
scene classifier (graph_native | phase_history | custom_object | document_scene)
      |
      v
deterministic normalizer -> nodes[] + edges[]
      |
      v
id-based node upsert + edge dedupe
      |
      v
graph/graph.json (sorted, stable serialization)
```

## Cross-Artifact Constraints
- Operation order is classify -> normalize -> validate -> merge -> sort -> write.
- Normalization must be deterministic and side-effect free for unchanged inputs.
- Merge semantics are append-only in intent: existing unrelated nodes/edges must be preserved.

## Determinism and Drift Tests
- Input ordering: scene ingestion order must be lexical by normalized relative path.
- Node ordering: output nodes sorted by `id` ascending, tie-break by `type`.
- Edge ordering: output edges sorted by `from`, then `to`, then `type`.
- Serialization: UTF-8 JSON with two-space indentation.
- Drift test 1 (repeat-run): same inputs twice produce byte-identical `graph/graph.json`.
- Drift test 2 (permutation): ingesting same scene set in random order yields identical output.
- Drift test 3 (id collision): two definitions of same node id resolve via deterministic precedence (later path in lexical order wins).

## Governance Rules
- Versioning: behavior changes require new versioned spec/operation artifacts.
- Source-of-truth: scene artifacts remain authoritative; graph output is derived and may be regenerated.
- Schema-first: graph-native scenes should validate against `scenes/_schemas/graph_scene_v0.schema.json`.
- No silent mutation: every graph write must be visible in git diff.
- Failure must be explicit: unsupported scene shape returns non-zero and does not write partial state.

## Failure Modes
- Unsupported scene shape without required discriminator keys.
- Node objects without string `id` values.
- Edge objects missing `from`, `to`, or `type`.
- Invalid JSON in input scene or graph file.

## Success Criteria (v0)
- Scripted operation can ingest all in-scope scene types deterministically.
- Output graph contains deduplicated edges and id-upserted nodes.
- Repeat-run and permutation drift tests pass.
- Operation and schema artifacts are linked from the repository index.

## Immediate Next Step
Execute `operations/incorporate_scene_into_graph_v0.md` via `tools/sb_graph_ingest_v0.sh` on a small scene set, then run repeat-run drift verification.
