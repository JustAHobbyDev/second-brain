# OQ-3 Autonomy Risk Policy v0 (Draft)

Status: Draft (PROPOSE-only, not activated)
Prepared at: 2026-02-17T07:35:14Z
Scope: project/dan_personal_cognitive_infrastructure

## Purpose
Preserve autonomy by default while requiring pre-approval only for high-impact operations.

## Policy Mode
- Scoped advisory policy (non-blocking by default)
- No global hard gate behavior
- Human approval required only for high-impact tier

## Risk Tiers
- low: autonomous
- medium: autonomous with post-run audit
- high: human approval required before execution

## High-Impact Operations (v0)
1. spec activation (promoting draft/spec to active enforcement)
2. gate state changes (create/enable/disable/blocking behavior changes)
3. cross-scope writes that touch spec/, scene/authority/, gate surfaces, or span multi-project scope
4. external side effects (network mutations, external service state changes, infrastructure writes)

## No-Preapproval Allowlist Criteria (all required)
A recurring command is eligible for no-preapproval only when all criteria hold:
1. deterministic output for same inputs
2. narrow scoped target paths
3. idempotent behavior
4. no external side effects

## Review Clause
If this allowlist policy proves too restrictive in practice, revise criteria through PM consultation and record a new draft revision before activation.

## Example High-Impact vs Non-High-Impact
- High impact: activating a spec; changing a gate state; writing across project scopes including spec/.
- Medium: scoped scene/task updates with post-audit and no external side effects.
- Low: deterministic local report generation in a single scoped directory.

## Acceptance Criteria (Draft)
- Tier definitions are explicit and machine-legible.
- High-impact list is explicit with conditional cross-scope rule.
- Allowlist criteria require all four safety conditions.
- Policy remains advisory outside high-impact operations.
