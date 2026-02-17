# Governance Gradient Spec v0

## Purpose
Define a restrained governance gradient that reduces entropy without introducing overlapping mechanisms.

## Core Policy
- Binary governance target at stable state: 100% contract adherence for gated flows.
- Audits propose; audits do not auto-mutate project state.
- Ingest only traversable knowledge into graph exports; non-traversable guidance remains in `meta/`.
- Cross-repo edits are human-gated by default.
- Primary audit surfaces are git history and `reports/checkpoints/*`.
- Session closeout artifacts are legacy and non-primary in this repository.

## Cross-Repo Edit Gate
Default boundary rule:
- The active repository is the only writable target for agent edits.
- Any edit outside the active repository requires explicit human authorization in the current session before changes are made.
- Absence of explicit authorization means no cross-repo file edits, even if related policy exists in another repo.

Operational note:
- Cross-repo reads for context are allowed when needed.
- Cross-repo writes remain blocked unless explicitly granted.

## Invariant Mapping (1:1)
Each invariant must map to one primary enforcement mechanism.

| Invariant | Primary Mechanism | Level | Notes |
|---|---|---|---|
| Checkpoint provenance continuity | `.githooks/pre-commit` + `tools/sb_precommit_checkpoint.sh` + git history | 1 (hook gate) | Primary audit surface for mutation provenance. |
| Vision alignment drift | `scripts/run_vision_alignment_audit.py` + `operations/vision_alignment_audit_v0.md` | 2 (audit/track) | Proposes remediation only. |
| KPI rollups and health trends | `tools/sb_kpi_compute_v0.sh` + `scenes/kpi-dashboard.scene.json` | 2 (track-only) | No direct mutations. |
| Terminology consistency | `meta/TERMINOLOGY_STANDARD_v0.md` + `tools/sb_terminology_scan_v0.sh` | 2 (audit/track) | Escalate to level 3 only if repeated failures. |
| Graph derivation integrity | `tools/sb_graph_ingest_v0.sh` | 1 (hard gate on ingest run) | Scenes remain source of truth. |

## Entropy Guard
Ingest rule:
- Add to graph only if the data improves traversal/query utility.
- Keep process docs, governance policy, and non-traversable prose in `meta/`.

Practical filter:
- Traversable: scene nodes/edges, canonical IDs, artifact pointers used by workflows.
- Non-traversable: duplicate guidance, prose-only policy without node/edge utility.

## Verification
Quick check for 1:1 mechanism coverage:

```bash
jq -r '.[] | [.invariant, .primary_mechanism] | @tsv' <<'JSON'
[
  {"invariant":"checkpoint_provenance","primary_mechanism":"sb_precommit_checkpoint"},
  {"invariant":"vision_alignment","primary_mechanism":"run_vision_alignment_audit"},
  {"invariant":"kpi_rollups","primary_mechanism":"sb_kpi_compute"},
  {"invariant":"terminology_consistency","primary_mechanism":"sb_terminology_scan"},
  {"invariant":"graph_derivation","primary_mechanism":"sb_graph_ingest"}
]
JSON
```

If any invariant maps to multiple primary mechanisms, downgrade overlaps to track-only and keep a single gate owner.

## Invariant Mapping Table
Maps mechanisms to exactly one invariant (canonical ID + description).
Redundancy -> downgrade secondary mechanism to Track-only (Level 2).
Core gates (Level 3) require explicit decision artifact if overlap occurs.
KPI never enforces domain invariants - only tracks/alerts.

| Mechanism | Invariant ID | Description | Level | Action |
|---|---|---|---|---|
| Checkpoint Reports + Git | inv/checkpoint_provenance_continuity | Every commit emits checkpoint metadata and links to git history | 3 | Gate only |
| Terminology Standard | inv/term_fidelity_post_v0 | Term fidelity 100% (post-v0) | 2 | Audit + Alert |
| Usage Ritual | inv/preload_ritual | Pre-load (Direction/Gov/Term) | 1 | Ritual / Checklist |
| Vision Alignment Audit | inv/vision_alignment | Alignment to core principles | 2 | Propose change |
| KPI System | inv/observability_entropy | Observable entropy metrics | 2 | Track only |
| Meta-Program Loop | inv/agent_resumption_min_8 | Agent resumption >=8 | 3 | Gate on score |
| Graph Ingest | inv/derived_view_integrity | Derived view integrity | 2 | Dry-run default |
| Structural Audit (ASLB) | inv/structural_legibility_min_band | Structural legibility score >=16 (band) | 2 | Track + Refactor proposals |
| Kalshi Data Gate | inv/kalshi_data_windows_min_200 | Usable windows ≥200 for Kalshi pipeline | 3 | Scoped hard gate |

Rule: One mechanism per invariant_id. Overlap -> downgrade secondary to Level 2 unless core_gate=true. Escalate if violation frequency >2 in 7 days.

## Scoped Hard Gates (New Pattern)

**Definition**  
A **scoped hard gate** is a Level 3 enforcement mechanism that applies **only to a defined project or subsystem**, rather than globally across the entire second-brain.

**Characteristics**
- Blocks only work within the declared `scope`
- Explicitly permits all unrelated work
- Still functions as a true Level 3 gate (reject / fail) inside its scope
- Prevents over-constraining the broader system

**Canonical Example**
- `scene/kalshi_data_gate_v0` — blocks all changes to the Kalshi 15m BTC pipeline (Phase 10+ ladder work) until 200/200 usable windows, but allows governance, meta, tools, rituals, and other projects to proceed normally.

**When to Use**
- Use when a constraint is critical for one project but would create unwanted global paralysis if applied repo-wide.
- Prefer scoped gates over global ones when the invariant is domain-specific.

**Gradient Placement**
- Level: **3 (Hard Gate)** inside declared scope
- Level: **0 (Convention)** outside declared scope

**Rule for Future Gates**
Any new Level 3 gate must declare an explicit `scope` array. If no scope is declared, it defaults to global (and should be questioned during audit).

**Example in Invariant Mapping Table (add this row)**
| Mechanism                | Invariant ID                        | Description                              | Level | Action                  |
|--------------------------|-------------------------------------|------------------------------------------|-------|-------------------------|
| Kalshi Data Gate        | inv/kalshi_data_windows_min_200    | Usable windows ≥200 for Kalshi pipeline | 3     | Scoped hard gate       |
