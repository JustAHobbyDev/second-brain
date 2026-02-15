# Terminology Standard v0 (2026-02-15)

## Purpose
Prevent semantic drift and term conflation across the Second Brain.

This document standardizes usage of:
- Taxonomy
- Ontology
- Schema
- Meta-Model
- Knowledge Graph
- Artifact
- Spec
- Domain Model

Agents and humans must use these terms consistently.
Enforcement anchors: `meta/CLOSEOUT_CONTRACT_v0.md`, `operations/vision_alignment_audit_v0.md`, and `scripts/run_vision_alignment_audit.py`.
Audit KPI hook: track terminology-fidelity trend in session summaries, target 100% no-conflation in reviewed artifacts.
If ambiguity arises, this document is authoritative.

## Core Definitions

### 1. Taxonomy
A **hierarchical classification** of entities.

Characteristics:
- Tree structure
- `is-a` relationships only
- No behavioral constraints
- No relationship semantics beyond hierarchy

Example:
- `meta/SECOND_BRAIN_TAXONOMY_v0.md`

Non-example:
- A scene with cross-links between principles and artifacts (that is graph structure, not taxonomy).

### 2. Ontology
A **formal naming and definition of types, properties, and interrelationships** within a domain.

Characteristics:
- Extends taxonomy with semantics (for example: `implements`, `extends`, `aligned_with`)
- Includes constraints and meaning boundaries
- Domain-specific but reusable
- Supports inference-like reasoning over links and future query primitives (for example: "all artifacts implementing principle/X")

Example:
- `meta/ONTOLOGY_ARCHITECTURE_MAP_v0.md`

Non-example:
- Raw JSON with fields but no semantic model.

### 3. Schema
A **blueprint for data structure and validation** of a specific format.

Characteristics:
- Defines fields, types, and required/optional constraints
- Machine-enforceable
- Versioned
- Narrowly scoped to a structure, not full semantics

Example:
- `scenes/_schemas/graph_scene_v0.schema.json`

Non-example:
- A free-form README section.

### 4. Meta-Model
A **model of models** that describes how other models are structured and related.

Characteristics:
- Abstract layer above domain-specific models
- Governs how workflows generate or update lower-level models
- Supports agent reflection on process contracts
- Tool-agnostic

Example:
- `meta/META_PROGRAM_SPEC_v0.md`

Non-example:
- A single concrete scene file.

### 5. Knowledge Graph
A **network of entities (nodes) and relationships (edges)** representing knowledge.

Characteristics:
- Rich typed edges with semantics
- Derived from source scenes
- Queryable/traversable
- Evolves via ingest pipeline

Example:
- `graph/canonical.jsonl` (derived)
- `tools/sb_graph_ingest_v0.sh` (builder)

Non-example:
- A pure hierarchy with no cross-edge semantics.

### 6. Artifact
A **structured, immutable snapshot** of session output capturing decisions, links, and resumable state.

Characteristics:
- Canonical ID format (for example: `artifact/<llm>_YYYY_MM_DD_slug`)
- Link-rich
- Includes resumability fields
- Stored as durable JSON output

Example:
- `sessions/codex/2026-02-15-agent-owned-vision-audit-loop.json`

Non-example:
- Raw chat transcript without contract fields.

### 7. Spec
A **precise, executable specification** for process, behavior, or constraints.

Characteristics:
- Testable/auditable
- Versioned
- Declarative contract surface
- References models/schemas where relevant

Example:
- `meta/CLOSEOUT_CONTRACT_v0.md`

Non-example:
- Informal brainstorming notes in `OPEN_QUESTIONS.md`.

### 8. Domain Model
A **conceptual representation of a specific problem space** including entities, relationships, and governing rules.

Characteristics:
- Domain-specific coherence
- Integrates taxonomy and ontology viewpoints
- Expresses operational invariants
- Evolves with system maturity

Example:
- `scenes/dan_personal_cognitive_infrastructure.scene.json`

Non-example:
- Generic diagram with no repository-specific semantics.

## Usage Ritual
Before closing a meaningful session, self-check terminology:
- Did you use `taxonomy` only for hierarchy?
- Did you use `ontology` only for semantic relationships/constraints?
- Did you use `schema` only for structural validation contracts?
- Did you treat `graph` as derived and `scenes` as source of truth?
- Did artifact summaries avoid term conflation?

## Quick Differentiation Table
| Term | Primary Focus | Validation Surface | Repo Anchor |
|---|---|---|---|
| Taxonomy | Hierarchical classification | Naming and parent-child structure | `meta/SECOND_BRAIN_TAXONOMY_v0.md` |
| Ontology | Semantic relationships and constraints | Link semantics and model coherence | `meta/ONTOLOGY_ARCHITECTURE_MAP_v0.md` |
| Schema | Data structure and field constraints | Parser/schema validation | `scenes/_schemas/graph_scene_v0.schema.json` |
| Meta-Model | How models are defined and evolved | Workflow/process contracts | `meta/META_PROGRAM_SPEC_v0.md` |
| Knowledge Graph | Connected knowledge network | Ingest/traversal integrity | `graph/canonical.jsonl` |
| Artifact | Session state snapshot | Closeout contract checks | `meta/CLOSEOUT_CONTRACT_v0.md` |
| Spec | Executable process contract | Audits, tests, scripted gates | `operations/vision_alignment_audit_v0.md` |
| Domain Model | Problem-space conceptual model | Cross-scene coherence | `scenes/dan_personal_cognitive_infrastructure.scene.json` |

## Change Log
- v0 (2026-02-15): Initial standard with definitions, non-examples, usage ritual, and differentiation table.
