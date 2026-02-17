# Beads Boundary Audit Operation

Version: v0
Status: Track-only
Inputs:
- `scene/authority/registry_v0.json`
- `scene/merge_queue/queue_v0.json`
- `spec/beads_integration_boundary_v0.md`

## Purpose
Validate two minimal Beads hardening controls:

1. Authority registry churn guardrail for Beads-scoped tuples.
2. Runtime proposal materialization into `scenes/` before canonical recognition.

## Operation Signature
`run_beads_boundary_audit(repo_root?, registry_file?, merge_queue_file?, out_file?)`

## Procedure
1. Run:
   ```bash
   python3 scripts/run_beads_boundary_audit.py
   ```
2. Inspect output at:
   - `scene/audit_reports/v0/beads_boundary_audit_<YYYY_MM_DD>_v0.json`
3. If status is `warning`, remediate findings and re-run.

## Metrics (v0)
- `beads_tuples_scanned`
- `wildcard_scope_violations`
- `broad_scope_violations`
- `multi_surface_tuple_violations`
- `merged_items_scanned`
- `materialization_violations`

## Definition of Done
- [ ] Audit artifact emitted.
- [ ] Findings are machine-readable and scoped.
- [ ] No automatic mutation performed by this audit run.
