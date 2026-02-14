# Spec Spec

Version: v0
Status: Experimental
Inputs:
- `README.md` repository purpose and conventions
- `meta/*.md` existing spec artifacts
- `scenes/spec-spec-ontology.scene.json` canonical spec ontology scene
- `scenes/*.scene.json` linked principles, concepts, and patterns
- `meta/ONTOLOGY_ARCHITECTURE_MAP_v0.md` layered semantic stack

## Purpose
Define the foundational contract for all repository specs so governance, determinism, and evolution rules stay explicit and machine-checkable across domains.

## Scope
- In scope:
  - Canonical spec document shape and required sections
  - Spec naming, versioning, and status lifecycle
  - Inherited governance invariants for all child specs
  - Determinism and drift expectations for spec-governed workflows
- Out of scope:
  - Domain-specific implementation details of any single child spec
  - Tool-specific execution semantics unless codified by a child spec
  - Historical migration of pre-spec artifacts

## Core Definitions
- `Spec`: A versioned governance artifact with normative behavior and validation criteria.
- `Child Spec`: Any spec derived from this foundational spec for a narrower domain.
- `Spec Status Lifecycle`: `Experimental -> Stable -> Deprecated`.
- `Semantic Change`: Any behavioral, governance, contract, or interpretation change.
- `Editorial Change`: Non-semantic change (typos, wording clarity) that preserves behavior.

### Required Sections for Every Spec
1. Title
2. Version
3. Status
4. Inputs
5. Purpose
6. Scope
7. Core Definitions
8. Determinism and Drift Tests
9. Governance Rules
10. Failure Modes
11. Success Criteria
12. Immediate Next Step

### Layer Alignment
- Every spec must declare which semantic layer(s) from `meta/ONTOLOGY_ARCHITECTURE_MAP_v0.md` it governs or instantiates.
- Direction-only specs live at L0; governance specs at L1; meta-model definitions at L2; ontologies at L3; schemas at L4; operational specs affecting artifacts must reference the L5 instance layer.
- Child specs that span multiple layers must clearly separate intent (higher layers) from enforcement/representation (lower layers) to preserve agent legibility.

## Determinism and Drift Tests
- Structural determinism: required sections must appear exactly once and in canonical order.
- Version determinism: semantic changes require monotonic version bump (`vN -> vN+1`).
- Repeat-run drift test: deriving child outputs twice with identical inputs must produce byte-identical normalized outputs when the child spec claims deterministic serialization.
- Permutation drift test: reordering source discovery must not change governed output when ordering rules are defined.
- Boundary drift test: adding out-of-scope inputs must not change output unless scope/version changes.

## Governance Rules
- Naming convention: `<SCOPE>_<SUBJECT>_SPEC_vN.md` with monotonic `N` per subject.
- No silent mutation: all semantic changes must be visible in git diff and versioned.
- No in-place semantic rewrite: never repurpose an existing version to mean something new.
- Explicit over inferred: required behavior must be stated, not assumed.
- Fail closed: missing required contracts or ambiguous inputs must block execution rather than guess.
- Child derivation rule: all child specs must include all required sections and may only tighten (not weaken) inherited invariants unless version-bumped with rationale.
- Status lifecycle rules:
  - `Experimental`: breaking changes allowed with version bumps.
  - `Stable`: backward compatibility required unless major semantic shift is introduced with a new version.
  - `Deprecated`: frozen except metadata or migration guidance updates.

## Failure Modes
- Missing required sections or non-canonical section order.
- Ambiguous or non-monotonic version labels.
- Semantic changes shipped without version bump.
- Child spec weakening inherited invariants without explicit override rationale and new version.
- Determinism claims without concrete ordering/serialization rules.

## Success Criteria (v0)
- Foundational spec exists at `meta/SPEC_SPEC_v0.md`.
- Existing specs in `meta/` conform to required section set and structure.
- Spec naming/versioning rules are explicit and reusable for new subjects.
- Ontology references to Spec Spec resolve to an on-disk artifact.

## Immediate Next Step
Run a lightweight conformance pass over `meta/*.md` to flag section omissions and propose `v1` upgrades where invariants are currently implied but not explicit.
