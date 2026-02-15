Hyperfast mode route is active.

Execution contract:
1. Load scene: `scenes/hyperfast-agent-closeout.scene.json`.
2. Use protocol `hyperfast_agent_protocol` as the runtime execution route.
3. Constrain session loops to hyperfast bounds (3-5 iterations max unless explicit override).
4. Enforce closeout via `tools/sb_closeout.sh` and include scene fold suggestions in output.
5. If closeout threshold fails (`resumption_score < 6`), stop and emit remediation actions.

Output requirement:
- Emit concise execution summary with:
  - `hyperfast_mode`: true
  - `route_scene`: `scene/hyperfast-agent-closeout_v0`
  - `closeout_status`: pass/fail
  - `remediation_actions` (if fail)
