# Incorporate Scene Into Graph Operation

Version: v0
Status: Experimental
Inputs:
- Included folders: `scenes/`, `graph/`, `meta/`, `operations/`, `tools/`
- Excluded folders: `.git/`, `misc/`, temporary files
- Artifact classes: scene JSON artifacts, graph store, integration specs
- Source-of-truth policy: `scenes/*.scene.json` are canonical; `graph/graph.json` is an optional derived export

## Operation Signature
`incorporate_scene_into_graph(scene_path, graph_path?, mode?)`

## Parameters
- `scene_path` (required, string): path to one scene file or directory containing scene files.
- `graph_path` (optional, string): defaults to `graph/graph.json`.
- `mode` (optional, enum): `"apply" | "dry_run"` (default `"dry_run"`).

## Scene Classification Rules
- `graph_native`: has top-level `nodes` and `edges` arrays.
- `phase_history`: has `schema_version`, `project_id`, and `phase_events`.
- `custom_object`: has top-level `type` and either `id` or `artifact`.
- `document_scene`: fallback object scene; id is derived from `id`, `artifact`, or filename stem.
- Otherwise: fail with explicit error; do not mutate graph.

## Normalization Rules
- `graph_native`:
  - Use `nodes` and `edges` directly after field validation.
- `phase_history`:
  - Emit project node id `project/<project_id>`.
  - Emit one phase event node per event id `phase_event/<project_id>/<entered_on>/<phase>`.
  - Emit edges `project/<project_id> --has_phase_event--> phase_event/...`.
- `custom_object`:
  - Emit source node from top-level object preserving deterministic fields.
  - Source id resolution: `id` if present, otherwise `artifact`.
  - If `relations[]` exists, emit edges from source id to each `target` with edge `type` from relation.
- `document_scene`:
  - Emit source node with deterministic id resolution: `id` -> `artifact` -> filename stem.
  - Label resolution: `title` -> `meta.name` -> resolved id.
  - Summary resolution: `summary` -> `purpose` -> `meta.purpose`.
  - If `relations[]` exists, emit edges from source id to each `target` with edge `type` from relation.

## Merge Rules
- Node upsert key: `id`.
- Upsert precedence: lexical scene path order; later path wins for colliding ids.
- Edge dedupe key: `(from, to, type)`.
- Deterministic final ordering:
  - Nodes by `id` ascending, then `type`.
  - Edges by `from`, then `to`, then `type`.

## Determinism Guarantees
- Discovery order for directory input is lexical path order.
- Stable serialization: two-space JSON indentation and stable key ordering in script output.
- Dry-run emits deterministic summary of node/edge delta counts.

## Drift Tests
- Repeat-run stability:
  - Run operation twice with unchanged inputs; resulting `graph/graph.json` hash must match.
- Discovery-order invariance:
  - Ingest the same file set in randomized invocation order; output must match canonical run.
- Collision stability:
  - Provide two scenes with same node id; winner must be deterministic from path precedence.

## Failure Modes
- Input scene not valid JSON object.
- Graph file not valid object with `nodes[]` and `edges[]`.
- Missing required fields in normalized node/edge output.
- Unsupported shape due to absent discriminator fields.
- Non-object top-level JSON scene payload.

## Definition of Done
- [ ] Operation accepts single file and directory input.
- [ ] All supported scene shapes normalize into graph nodes/edges.
- [ ] Merge/upsert behavior is deterministic and documented.
- [ ] Drift tests pass on repeat and permuted runs.
- [ ] Dry-run mode reports deterministic deltas and performs no writes.

## Example Output (Dry Run)
```json
{
  "mode": "dry_run",
  "graph_path": "graph/graph.json",
  "scenes_processed": 2,
  "nodes_added": 3,
  "nodes_updated": 1,
  "edges_added": 4,
  "edges_deduped": 2
}
```
