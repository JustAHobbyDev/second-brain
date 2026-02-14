## Title
Agent Structural Legibility Benchmark (ASLB) v0

## Purpose
Measure whether the Second Brain corpus is **structurally recoverable** by an autonomous agent with no prior instruction.

"Structurally legible" means an agent can infer:
- hierarchy / partitions
- ontology primitives (node/edge/lifecycle)
- governance rules (mutation/versioning/lineage)
- declared intent (North Star / design charter)
- drift (misalignment between derived structure and declared intent)

This benchmark exists to make "agent-comprehensibility" measurable, trackable, and regressible over time.

---

## Core Hypothesis
If multiple independent agents (different models and/or runs) reconstruct similar structures from the same corpus, then the structure is:
- embedded in artifacts (not prompt-dependent)
- stable enough for automation
- suitable for drift detection and self-auditing agents

---

## Inputs
### Required
- A snapshot of the Second Brain corpus (repo state, folder, or export).
- The North Star + Design Charter artifacts.

### Optional
- An explicit glossary (if present).
- Any schemas/specs describing artifacts, nodes, relationships, or versioning.

---

## Outputs
Each benchmark run must produce a deterministic, machine-readable result record:

```
{
  "timestamp": "ISO-8601",
  "corpus_ref": "git_sha_or_snapshot_id",
  "model": "string",
  "prompt_set_version": "v0",
  "tier_scores": {
    "taxonomy": 0,
    "ontology": 0,
    "governance": 0,
    "direction": 0,
    "drift_detection": 0
  },
  "aggregate_score": 0,
  "confidence": "low|medium|high",
  "derived_taxonomy": "string_or_structured_tree",
  "derived_ontology": {
    "node_types": [],
    "edge_types": [],
    "lifecycle_states": [],
    "invariants": []
  },
  "governance_inference": {
    "rules": [],
    "risks": [],
    "tests_suggested": []
  },
  "direction_inference": {
    "north_star_guess": "string",
    "charter_guess": "string",
    "evidence": []
  },
  "drift_report": {
    "misalignments": [],
    "category_creep": [],
    "redundancy": [],
    "refactor_suggestions": []
  },
  "notes": "string"
}
```

---

## Scoring Model

The ASLB consists of 5 tiers, each scored 0–5, for a 0–25 aggregate.

Scoring is ordinal and should be consistent across runs. If uncertain, score lower and annotate confidence.

### Aggregate Bands

- 0–8 Fragmented notebook
- 9–15 Structured system
- 16–20 Agent-comprehensible
- 21–25 Self-reflective infrastructure

### Tier 1: Taxonomy Recoverability (0–5)

**Prompt Goal**  
Derive a hierarchical taxonomy of the system from artifacts alone.

**Pass Criteria Signals**
- “Direction” (or equivalent) is near the top.
- Clear separation between: Principles, Concepts, Patterns/Workflows, Tools/Infra, Operations, Artifacts.
- Projects/domains appear as distinct subtrees (e.g., Kalshi pipeline).
- Taxonomy is coherent (not a flat list, not random clustering).

**Scoring Guide**
- 0: flat list / incoherent buckets
- 1: weak clustering, major category confusion
- 2: some clusters, hierarchy mostly arbitrary
- 3: coherent hierarchy with minor misplacements
- 4: strong hierarchy; matches corpus structure well
- 5: strong hierarchy + recognizes implicit partitions not explicitly labeled

### Tier 2: Ontology Extraction (0–5)

**Prompt Goal**  
Infer ontology primitives: node types, edge types, lifecycle states, invariants.

**Pass Criteria Signals**
- Identifies candidate knowledge object classes (e.g., Artifact, Spec, Principle, Concept, Pattern, OpenQuestion).
- Identifies relationship types (e.g., derives_from, references, governs, implements, contradicts, supersedes).
- Identifies lifecycle states (draft/canonical/deprecated or equivalent).
- Identifies at least 2–3 invariants (e.g., version monotonicity, immutable schemas, explicit lineage).

**Scoring Guide**
- 0: no ontology primitives inferred
- 1: vague categories only
- 2: node types inferred; edges/lifecycle weak
- 3: node + edge + lifecycle plausible
- 4: strong primitives with evidence and examples
- 5: ontology aligns with corpus conventions and anticipates missing formalization

### Tier 3: Governance Inference (0–5)

**Prompt Goal**  
Infer the implicit rules governing integrity: mutation policy, versioning, determinism, lineage.

**Pass Criteria Signals**
- Detects constraints like: “no silent mutation”, “no in-place semantic rewrites”, “explicit over inferred”.
- Recognizes versioning semantics (monotonic vN, immutable schemas, “new file for breaking change”).
- Identifies deterministic serialization expectations (stable formatting/keys, reproducibility).
- Produces candidate tests or checks to enforce governance.

**Scoring Guide**
- 0: no governance inferred
- 1: generic “be consistent” advice
- 2: detects some rules but not actionable
- 3: actionable governance rules inferred
- 4: rules + proposed checks + risk identification
- 5: governance model is specific, testable, and matches corpus behavior

### Tier 4: Directional Alignment (0–5)

**Prompt Goal**  
Infer the system’s North Star and design charter from artifacts.

**Pass Criteria Signals**
- Identifies AI-native nature (agent-operable artifacts, machine comprehension).
- Identifies compounding over time (cognitive compounding / durable knowledge objects).
- Identifies ontology/semantic linking as core (not just “notes”).
- Identifies execution linkage (knowledge → decisions → specs → tasks → artifacts).

**Scoring Guide**
- 0: wrong direction / generic productivity framing
- 1: partially correct but misses key themes
- 2: recognizes one core theme only
- 3: matches most key themes
- 4: concise accurate North Star + charter
- 5: direction inferred + traced to evidence in corpus + correctly distinguishes what system is not

### Tier 5: Drift Detection (0–5)

**Prompt Goal**  
Compare derived structure to declared North Star/Charter and flag drift.

**Pass Criteria Signals**
- Detects category creep (tools overfitting, clutter, accidental scope expansion).
- Detects governance inconsistencies (naming/versioning/lineage breaks).
- Detects redundancy or fragmentation (duplicate concepts, competing specs).
- Produces concrete refactor proposals (move/merge/split/rename) tied to intent.

**Scoring Guide**
- 0: no drift analysis
- 1: generic “keep it tidy” advice
- 2: flags issues but not connected to direction
- 3: actionable drift findings tied to intent
- 4: strong findings + prioritized refactors
- 5: strong findings + proposed regression tests + clear evidence trail

---

## Prompt Set (v0)

This spec does not mandate exact wording, but the following intent must be preserved.

- **Taxonomy** — “Given this corpus, derive a hierarchical taxonomy of the system.”
- **Ontology** — “Infer node types, edge types, lifecycle states, and invariants implied by this corpus.”
- **Governance** — “Infer the rules governing mutation, versioning, determinism, and lineage.”
- **Direction** — “Infer the North Star and design charter of this system; cite evidence.”
- **Drift** — “Compare derived structure to declared direction; identify misalignments and propose refactors and tests.”

---

## Run Cadence

Recommended:

- Run ASLB on demand for major refactors.
- Run monthly for drift detection.
- Run before/after introducing new major subsystems (e.g., prompt lineage, spec governance, graph schema).

---

## Reproducibility Notes

- Record corpus reference (git SHA) for every run.
- Record the exact model identifier.
- Save prompts used (or prompt_set_version + template).
- Prefer deterministic settings where available; if not, run N=3 and compare variance.

---

## Success Condition

The Second Brain is considered agent-comprehensible when:

- Aggregate score ≥ 16/25, and
- No tier is below 3/5, and
- Results are stable across at least two different models or two runs (variance small enough to not change aggregate band).

---

## Future Extensions

- Add a “variance score” across N runs and/or models.
- Add corpus sampling strategies (full vs recent vs per-project).
- Add a formal “evidence citation” contract (path + excerpt hashes).
- Add automated regression checks (“structural CI”) for governance.
