# Shell Embedding Audit Operation

Version: v0  
Status: Track-only  
Inputs:
- `tools/**/*.sh` and other bash-shebang scripts

## Purpose

Continuously audit embedded Python heredoc usage inside bash scripts so extraction opportunities are visible in recurring audits.

## Operation Signature

`run_shell_embedding_audit(repo_root?, out_file?)`

## Parameters

- `repo_root` (optional, default repo root): repository root path.
- `out_file` (optional, default `reports/shell_embedding_audit_v0.json`): JSON output path.

## Metrics (v0)

- `total_bash_scripts`
- `bash_with_embedded_python`
- `embedded_python_pct`
- `embedded_python_blocks`
- `embedded_python_lines_total`
- `max_block_lines`
- `unclosed_blocks`

## Advisory Thresholds (track-only)

- `embedded_python_pct_warn_gt`: `70.0`
- `max_block_lines_warn_gt`: `140`
- `unclosed_blocks_warn_gt`: `0`

## Procedure

1. Run:
   ```bash
   python3 scripts/run_shell_embedding_audit.py
   ```
2. Inspect `reports/shell_embedding_audit_v0.json`.
3. Prioritize top offenders for extraction into shared `scripts/*.py` modules when practical.
4. Keep inline Python for short, single-purpose glue code.

## Definition of Done

- [ ] Report JSON generated.
- [ ] Offenders and top offenders listed.
- [ ] Track-only alerts emitted when thresholds are crossed.
- [ ] No automatic mutation performed by this audit run.
