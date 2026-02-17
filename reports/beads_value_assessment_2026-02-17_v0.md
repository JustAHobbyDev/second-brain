# Beads Value Assessment v0

Date: 2026-02-17
Assessor: agent/codex
Scope: project/dan_personal_cognitive_infrastructure
Status: advisory

## Question
Would `https://github.com/steveyegge/beads` provide substantial value to this second-brain project?

## Executive Verdict
Yes, with boundary constraints.

- High value as a scoped runtime orchestration layer for multi-agent coordination.
- Low value (and high risk) if used as a replacement for canonical truth surfaces.
- Recommended posture: shadow-mode pilot only, then measured promotion decision.

## Context Alignment
Current architecture explicitly separates:

- `scenes/` as canonical epistemic source-of-truth.
- `scene/` as runtime execution state.

Relevant local specs:

- `spec/scene_namespace_boundary_v0.md`
- `spec/multi_agent_mutation_authority_model_v0.md`
- `spec/overstory_alignment_layer_v0.md`
- `meta/PUBSUB_BUS_SPEC_v0.md`

## Where Beads Adds Real Value
- Built-in dependency-native issue graph can reduce manual queue choreography.
- Agent coordination primitives can replace ad hoc claim/release handling.
- Local-first operation supports deterministic workflows without mandatory cloud coupling.
- Merge/review workflow structure can reduce coordination entropy once agent count grows.

## Risks and Mismatches
- State-surface duplication risk: Beads runtime state can be confused with canonical truth.
- Boundary drift risk: direct writes into canonical artifacts from orchestration runtime.
- Governance risk: branch-sync/protected-branch features can exceed current scoped policy.
- Coupling risk: introducing Beads before clear recurring-consumer pressure adds surface area without clear payoff.

## Recommendation
Adopt Beads only under a strict integration boundary:

- Treat Beads as runtime (`scene/` and `state/` class surfaces), never canonical truth.
- Keep canonical decisions in `scenes/` with explicit materialization from runtime outcomes.
- Keep pilot Level 2 / track-only.
- Do not enable branch-sync mode in pilot.
- Exclude blocked Kalshi pipeline mutation scope from pilot execution.

## Pilot Success Signal (proposed)
Promote only if all are true:

- `invariant_violations == 0`
- `cross_namespace_violations == 0`
- `blocked_scope_mutations == 0`
- `decision_materialization_coverage == 100%`
- `completed_cycles >= 3`
- `coordination_overhead_reduction_pct >= 20` (or mark `insufficient_data`)

## Sources
- https://github.com/steveyegge/beads
- https://steveyegge.github.io/beads/
- https://steveyegge.github.io/beads/get-started/quickstart/
- https://steveyegge.github.io/beads/reference/agent-coordination/
- https://steveyegge.github.io/beads/reference/formulas/
- https://steveyegge.github.io/beads/reference/molecules/
- https://steveyegge.github.io/beads/reference/gates/
- https://steveyegge.github.io/beads/use-cases/protected-branches/branch-sync-mode/
- https://raw.githubusercontent.com/steveyegge/beads/main/SECURITY.md
