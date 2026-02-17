# Vision Alignment Audit Operation

Version: v0
Status: Experimental
Inputs:
- `sessions/*/*.json` session artifacts (legacy; may be sparse as tracking is externalized)
- `scenes/*.scene.json` canonical principle IDs

## Purpose
Compute and persist the first vision-alignment KPI:
- `principle_linked_artifact_pct`

## Operation Signature
`run_vision_alignment_audit(sessions_dir?, out_file?, mutate?, trigger_out_file?)`

## Parameters
- `sessions_dir` (optional, default `sessions/`): session artifact root.
- `out_file` (optional, default `reports/vision_alignment_audit_v0.json`): JSON output path.
- `mutate` (optional, default `no`): `no` = propose only, `yes` = emit remediation trigger file.
- `trigger_out_file` (optional, default `reports/vision_alignment_audit_trigger_v0.json`): output path for proposed remediation trigger.

## KPI Definition (v0)
- `principle_linked_artifact_pct = 100 * artifacts_with_principle_link / eligible_artifacts`
- Eligible artifacts:
  - Non-empty summary
  - At least one decision or next step
- Principle link counts only if linked principle IDs are canonical IDs found in `scenes/`.

## Targets
- Pass: `>=75%`
- Stretch: `>=85%`

## Procedure
1. Run (propose-only default):
   ```bash
   python3 scripts/run_vision_alignment_audit.py
   ```
2. Optional: generate a remediation trigger (still no direct scene mutation):
   ```bash
   python3 scripts/run_vision_alignment_audit.py --mutate yes
   ```
3. Inspect report at `reports/vision_alignment_audit_v0.json`.
4. If below pass threshold, prioritize backfilling principle links in low-coverage artifacts.
5. If using `--mutate yes`, review `reports/vision_alignment_audit_trigger_v0.json` manually before any changes.

## Definition of Done
- [ ] Report JSON generated.
- [ ] KPI value and status computed.
- [ ] Missing-principle artifact IDs listed.
- [ ] Next actions captured.
- [ ] No automatic scene mutation performed by audit run.

## Recurring Audit Loop Integration

When running `tools/sb_agent_audit_loop.sh`, this vision audit is paired with:

- `scripts/run_shell_embedding_audit.py`
- Output: `reports/shell_embedding_audit_v0.json`
- `scripts/run_namespace_boundary_audit.py`
- Output: `reports/namespace_boundary_audit_v0.json`

All audit reports are attached to the generated recurring audit summary report for review.

Recurring loop also runs:

- `scripts/run_secret_scan_audit.py`
- Output: `reports/secret_scan_audit_v0.json`
