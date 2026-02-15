Run the vision-alignment audit operation now.

Execution:
1. Run:
   python3 scripts/run_vision_alignment_audit.py --out-file reports/vision_alignment_audit_v0.json
2. Read the generated report.
3. If KPI status is fail, propose the top 3 link-remediation actions (artifact IDs first).
4. Emit a concise JSON summary with:
   - artifact_id
   - kpi.name
   - kpi.value_pct
   - kpi.status
   - next_actions (top 3)

Constraints:
- Do not mutate historical session artifacts in this step.
- Reference canonical IDs only.
- Keep outputs deterministic.
