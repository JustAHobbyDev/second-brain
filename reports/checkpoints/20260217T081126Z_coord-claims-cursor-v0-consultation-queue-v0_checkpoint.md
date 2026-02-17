# Pre-Commit Checkpoint

- timestamp_utc: 2026-02-17T08:11:26Z
- branch: main
- head_before_commit: 8be8f7b
- work_slug: coord-claims-cursor-v0-consultation-queue-v0
- files_changed: 11
- insertions: 515
- deletions: 22

## Staged Files

```text
M	coord_claims.md
M	scene/agent/auditor/cursor_v0.json
M	scene/agent/project_manager/consultation_queue_v0.json
M	scene/agent/project_manager/cursor_v0.json
M	scene/agent/project_manager/ideas_v0.json
M	scene/agent/project_manager/status_v0.json
A	scene/audit_reports/v0/oq3_autonomy_risk_policy_spec_audit_2026-02-17_v0.json
M	scene/ledger/mutations_v0.jsonl
M	scene/task_queue/v0.json
A	spec/oq3_autonomy_risk_policy_v0.md
M	state/coord_kpi_v0.json
```

## Diffstat

```text
 coord_claims.md                                    |  51 ++++++++++
 scene/agent/auditor/cursor_v0.json                 |   8 +-
 .../project_manager/consultation_queue_v0.json     | 101 ++++++++++++++++++-
 scene/agent/project_manager/cursor_v0.json         |  10 +-
 scene/agent/project_manager/ideas_v0.json          |  14 ++-
 scene/agent/project_manager/status_v0.json         | 108 +++++++++++++++++++--
 ...onomy_risk_policy_spec_audit_2026-02-17_v0.json |  41 ++++++++
 scene/ledger/mutations_v0.jsonl                    |  51 ++++++++++
 scene/task_queue/v0.json                           | 100 +++++++++++++++++++
 spec/oq3_autonomy_risk_policy_v0.md                |  45 +++++++++
 state/coord_kpi_v0.json                            |   8 +-
 11 files changed, 515 insertions(+), 22 deletions(-)
```
