# ONTOLOGY_ARCHITECTURE_MAP_v0.md

## Title
Layered Ontology Architecture Map v0

## Purpose

Define the layered semantic architecture of the Second Brain so that:

- Humans can reason about its structure
- Agents can ground themselves deterministically
- Governance boundaries are explicit
- Ontologies, schemas, and instances are not conflated
- Structural drift can be detected

This document describes **how meaning is layered**, not where specific files live (though conventions are suggested).

---

# Overview

The Second Brain operates as a **6-layer semantic stack**.

Top layers define intent and constraints.  
Lower layers encode structure and instances.

```
L0 Direction
L1 Governance
L2 Meta-Model
L3 Ontology
L4 Schema / Representation
L5 Instance (Knowledge Graph Corpus)
```

Each layer depends only on layers above it.

---

# L0 — Direction Layer

**Purpose:** Define why the system exists.

Contains:
- North Star
- Design Charter
- Strategic intent

Defines:
- Optimization target
- What the system is *not*
- Long-term orientation

No structural rules live here — only intent.

---

# L1 — Governance Layer

**Purpose:** Define system integrity rules.

Examples:
- No silent mutation
- No in-place semantic rewrites
- Version monotonicity (vN)
- Breaking changes require new artifact
- Deterministic serialization
- Explicit lineage over inferred lineage

Governance defines what is allowed to change and how.

This layer enforces system stability across time.

---

# L2 — Meta-Model Layer

**Purpose:** Define what kinds of objects exist in the system.

This is an ontology about the modeling system itself.

Examples:
- Artifact
- Spec
- Ontology
- PromptArtifact
- PromptDelta
- SessionArtifact
- OpenQuestion
- DecisionRecord

If the system defines what a "Spec" must contain, that rule lives here.

Example artifact:
- `SPEC_SPEC_vN.md`

The Meta-Model defines:
- Allowed artifact classes
- Required sections
- Lifecycle states
- Cross-artifact contracts

---

# L3 — Ontology Layer

**Purpose:** Define semantic meaning within domains.

Contains:
- Agent Ontology
- Prompt Lineage Ontology
- Hyperfast Programming Ontology
- Kalshi Domain Ontology
- Future domain models

Defines:
- Node types (classes)
- Edge types (relationships)
- Domain constraints
- Execution loops (if relevant)

Important distinction:
- Ontology defines meaning
- Schema defines representation

Multiple ontologies can coexist.

---

# L4 — Schema / Representation Layer

**Purpose:** Define serialization and validation contracts.

Examples:
- JSON schemas
- Index file formats
- Graph scene schema
- Deterministic key ordering
- UTF-8 + formatting standards

This layer ensures:
- Reproducibility
- Deterministic diffs
- Machine validation
- Structural stability

Schemas enforce structure.
Ontologies define meaning.

---

# L5 — Instance Layer

**Purpose:** Store actual knowledge artifacts.

Examples:
- Session outputs
- Specs
- Derived summaries
- Extracted concept nodes
- Linked artifacts
- Project documents

This layer forms the actual **knowledge graph substrate**.

If relationships are instantiated (A derives_from B), that occurs here.

---

# Layer Interaction Model

Information flows downward during creation:

```
Raw input
↓
Session artifact (L5)
↓
Linked via ontology relations (L3)
↓
Validated against schema (L4)
↓
Constrained by governance (L1)
↓
Evaluated against direction (L0)
```

Structural inference flows upward during audit:

```
Instances (L5)
↑
Inferred ontology (L3)
↑
Inferred meta-model (L2)
↑
Inferred governance (L1)
↑
Inferred direction (L0)
```

If upward inference fails, the system is not agent-legible.

---

# Agent Grounding Order

When an autonomous agent enters the system, it must ground in this order:

1. L0 — Direction (what matters)
2. L1 — Governance (what is allowed)
3. L2 — Meta-Model (what object types exist)
4. L3 — Ontology (how objects relate)
5. L4 — Schema (how objects are encoded)
6. L5 — Instances (actual content traversal)

Agents must not modify L3–L5 without understanding L1.

---

# Structural Drift Detection

Drift occurs when:

- L5 instances imply a structure inconsistent with L3.
- L3 implies behavior inconsistent with L1.
- L1 rules conflict with L0 intent.
- Tooling encodes behavior not declared in governance.

Periodic structural audits should:
- Reconstruct taxonomy from L5 upward.
- Compare inferred L0 against declared L0.
- Flag misalignment.

---

# Design Invariants

The Second Brain aspires to:

- Be legible to independent agents.
- Allow ontology reconstruction from artifacts.
- Separate meaning (ontology) from representation (schema).
- Separate intent (direction) from enforcement (governance).
- Enable compounding intelligence over time.

---

# Maturity Signal

The system reaches structural maturity when:

- Independent agents derive similar L2–L3 structures.
- Governance can be inferred without instruction.
- Direction can be reconstructed from artifacts.
- Drift can be detected automatically.

At that point, the Second Brain becomes:

A machine-comprehensible cognitive infrastructure.
