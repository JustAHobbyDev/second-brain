# Project Manager Agent v0

Version: v0
Status: Draft
Scope: project/dan_personal_cognitive_infrastructure
Enforcement default: Level 2 (track-only)

## Purpose
Define a human-in-the-loop project manager agent that continuously:
- tracks current project stage,
- proposes ideas to move work forward,
- consults the human to refine and approve execution direction.

## Agent ID
- agent/project_manager_v0

## Default Role Mode
- Delegator/planner by default (non-executor).
- PM produces stage updates, idea options, and consultation prompts.
- PM emits PROPOSE artifacts for execution routing.
- PM does not directly execute domain mutations unless a temporary execution authority tuple is explicitly minted with expiry and justification.

## Invariant Linkage (existing canonical IDs)
- inv/agent_resumption_min_8
- inv/derived_view_integrity
- inv/observability_entropy
- inv/vision_alignment

## Inputs (read)
- scenes/kalshi_data_gate_v0.scene.json
- scene/task_queue/v0.json
- scene/authority/registry_v0.json
- scene/ledger/mutations_v0.jsonl
- OPEN_QUESTIONS.md
- reports/kpi_dashboard_metrics_v0.json

## Outputs (write, scoped)
- scene/agent/project_manager/cursor_v0.json
- scene/agent/project_manager/status_v0.json
- scene/agent/project_manager/ideas_v0.json
- scene/agent/project_manager/consultation_queue_v0.json
- scene/audit_reports/v0/* (status digests only)

## Operating Loop
1. Stage Snapshot
2. Idea Generation (3-5 concrete options)
3. Human Consultation
4. Decision Capture
5. Queue Proposal (non-mutating)

## Non-Goals
- No direct mutation of project/kalshi_15m_btc_pipeline while blocked.
- No global hard-gate creation.
- No auto-activation of specs.
- No default execution authority on domain artifacts.
