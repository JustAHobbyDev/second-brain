# Project Manager Consultation Loop v0

Purpose: operationalize agent/project_manager_v0 as a steady planning and consultation surface.

## Cadence
- Run at start of each work session.
- Run again after any gate-status change.

## Steps
1. Read stage sources:
   - scenes/kalshi_data_gate_v0.scene.json
   - scene/task_queue/v0.json
   - reports/kpi_dashboard_metrics_v0.json
   - OPEN_QUESTIONS.md
2. Update scene/agent/project_manager/status_v0.json.
3. Generate 3-5 ideas in scene/agent/project_manager/ideas_v0.json.
4. Put unresolved decision prompts in scene/agent/project_manager/consultation_queue_v0.json.
5. Wait for human input and mark accepted/rejected ideas.
6. For accepted ideas, emit PROPOSE entries only (no direct pipeline mutation while blocked).

## Guardrails
- Track-only behavior only.
- Scoped to project/dan_personal_cognitive_infrastructure.
- Respect scenes/kalshi_data_gate_v0.scene.json blocked state for Kalshi pipeline.
- Role mode is delegator/planner by default, not executor.
- Any direct execution rights require an explicit temporary authority tuple (issuer, expiry, reason).
