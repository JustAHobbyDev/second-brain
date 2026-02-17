# Invariant Drift Detection v0 (Draft)

Status: Draft (PROPOSE-only, not activated)
Owner (draft): agent/orchestrator_v0
Prepared at: 2026-02-16T22:37:53Z
Scope: project/dan_personal_cognitive_infrastructure

## Purpose
Define passive, machine-checkable invariant drift detection so the system can detect when observed structure no longer aligns with declared vision and invariant policy.

## Invariant Linkage
- inv/scenes_source_of_truth
- inv/agents_resume_cold
- inv/vision_alignment
- inv/derived_view_integrity

## Constraints
- Level 2 track-only only
- Passive monitoring only (no auto-mutation)
- No global hard-gate changes
- No blocking impact to project/kalshi_15m_btc_pipeline

## Execution Model (v0)
- Runner: agent/orchestrator_v0 (or delegated scoped maintainer with equivalent track-only authority)
- Cadence: at least once per PM cycle, and on-demand after major structural changes
- Inputs:
  - required: reports/kpi_dashboard_metrics_v0.json
  - optional: graph/graph.json
  - contextual: recent session artifacts under sessions/*/*.json

## Policy Thresholds (v0)
- principle_linked_pct_min: 75.0 (percent, 0-100 scale)
- orphan_ratio_max_pct: 10.0 (percent, 0-100 scale)
- coverage_from_core_min_pct: 80.0 (percent, 0-100 scale)

These thresholds are the normative trigger values for this v0 drift mechanism.

## Drift Detection Triggers (v0)
1. trigger/principle_linked_pct_below_min
   - metric: principle_linked_pct
   - condition: observed < 75.0
2. trigger/orphan_ratio_above_max
   - metric: orphan_ratio
   - condition: observed > 10.0
3. trigger/coverage_from_core_below_min
   - metric: coverage_from_core
   - condition: observed < 80.0

All triggers are machine-checkable from local artifacts and must be evaluated independently.

## Metric Source Map (normative)
- principle_linked_pct -> reports/kpi_dashboard_metrics_v0.json :: metrics.principle_linked_pct
- orphan_ratio -> reports/kpi_dashboard_metrics_v0.json :: metrics.orphan_ratio
- coverage_from_core -> reports/kpi_dashboard_metrics_v0.json :: metrics.coverage_from_core

If any mapped metric path is missing or non-numeric, the trigger must be emitted with status
insufficient_input and include a note describing the missing source field.

## Missing Input Behavior (v0)
- If reports/kpi_dashboard_metrics_v0.json is missing or unreadable, emit one report with
  status insufficient_input for all triggers and skip threshold comparisons.
- If graph/graph.json is missing, do not fail; rely on KPI-derived fields from
  reports/kpi_dashboard_metrics_v0.json.
- Missing-input states are warnings, not hard blocks.

## Reporting Protocol (v0)
1. Emit a report artifact under scene/audit_reports/v0/.
2. Include timestamp, scope, source artifacts, trigger evaluations, impacted artifact IDs, and invariant links.
3. Emit remediation as PROPOSE-only actions; no direct mutation or activation.
4. Sort trigger events by trigger_id for deterministic output ordering.

## Candidate Report Schema (v0)
```json
{
  "artifact_id": "artifact/invariant_drift_report_<date>_v0",
  "schema_version": "0.1",
  "generated_at": "<timestamp>",
  "scope": "project/dan_personal_cognitive_infrastructure",
  "source_artifacts": [
    "reports/kpi_dashboard_metrics_v0.json",
    "graph/graph.json"
  ],
  "trigger_events": [
    {
      "trigger_id": "trigger/principle_linked_pct_below_min",
      "metric": "principle_linked_pct",
      "source_path": "reports/kpi_dashboard_metrics_v0.json::metrics.principle_linked_pct",
      "observed": "<value>",
      "threshold": "<value>",
      "status": "violated|warning|pass|insufficient_input",
      "severity": "high|medium|low",
      "evaluator_note": "<optional>",
      "invariant_links": [
        "inv/vision_alignment"
      ]
    }
  ],
  "affected_artifacts": [
    "<artifact_id>"
  ],
  "proposed_remediations": [
    "<action>"
  ],
  "invariant_links": [
    "inv/vision_alignment",
    "inv/derived_view_integrity"
  ],
  "resumption_score": "<optional 0-10>"
}
```

## Acceptance Criteria (Draft)
- Triggers are machine-checkable from local artifacts with explicit thresholds.
- Report protocol is deterministic and replayable.
- Replay check: same inputs produce identical report content except generated_at.
- Output remains non-executing until explicit human approval.

## Threshold Governance (v0)
- Threshold owner: agent/orchestrator_v0 (proposal owner) with human approval required for changes.
- Change protocol: any threshold change requires a new draft revision entry and explicit consult resolution before activation.
- Versioning rule: threshold changes must increment draft revision metadata in this spec.

## Evaluator Implementation Task (v0)
- Required implementation artifact: tools/sb_invariant_drift_eval_v0.sh
- Output target: scene/audit_reports/v0/invariant_drift_report_<date>_v0.json
- Mode: track-only, report generation only, no auto-remediation.

