# Claude Session Closeout Runbook

Status: Legacy (deprecated default)

Purpose: deterministically capture a Claude session artifact, register it in the index, checkpoint the repo state, and commit the change set so downstream automations discoverable the new session.

Note: session writes under `sessions/` are deprecated by default in `project/second-brain`.
Use this runbook only for controlled migration/backfill workflows.

## Preconditions
- Working tree clean (`git status -sb` shows no staged/unstaged files) or you understand existing changes.
- Session JSON payload is ready (validated against `prompts/session_ending_prompt.md` schema).
- Runbook assumes commands execute from the repository root (`second-brain/`) without exposing parent directory paths.

## Ritual Steps
1. **Create session artifact**
   - Path: `sessions/claude/YYYY-MM-DD-<slug>.json` (relative path only; do not echo parent directories or external paths).
   - Command: `cat <<'EOF' > sessions/claude/2026-02-15-example-slug.json ...`.
   - Validate by `jq '.' sessions/claude/...json` (ensures valid JSON).

2. **Update session index**
   - File: `sessions/claude/index.json`.
   - Append new entry under `artifacts` array with `id`, `date`, `resumption_score`, concise `summary_snippet`.
   - Refresh `last_updated` to current UTC ISO timestamp.
   - Verify via `jq '.' sessions/claude/index.json` and visually confirm ordering.

3. **Stage artifacts**
   - `git add sessions/claude/<artifact>.json sessions/claude/index.json`.
   - Confirm staged set: `git status -sb`.

4. **Generate checkpoint report**
   - Run `tools/sb_precommit_checkpoint.sh`.
   - Script emits:
     - New timestamped report in `reports/checkpoints/`.
     - Updates `reports/checkpoints/LATEST.md`.
     - Appends to `reports/checkpoints/index.jsonl`.
   - Stage new/modified checkpoint files: `git add reports/checkpoints/*`.
   - Re-run `git status -sb` to ensure only expected files are staged.

5. **Commit**
   - Message convention: `Add Claude session closeout and checkpoint`.
   - Command: `git commit -m "Add Claude session closeout and checkpoint"`.
   - Confirm clean tree/ahead status via `git status -sb`.

6. **(Optional) Push**
   - If remote sync desired: `git push`.

## Verification Checklist
- `jq` validation passes for both JSON files.
- `sessions/claude/index.json` includes the new artifact id and accurate timestamp.
- `reports/checkpoints/LATEST.md` reflects latest timestamp/work slug referencing the session.
- `git status -sb` clean (or only ahead of remote) after commit.

## Troubleshooting
- **Script fails due to unstaged files**: return to Step 3, stage required inputs first.
- **Checkpoint slug undesirable**: re-run `tools/sb_precommit_checkpoint.sh` after adjusting staged file names; script derives slug from staged names.
- **Need to redo closeout**: amend the JSON, rerun steps 2–5 (script can be rerun; it will create a fresh checkpoint with new timestamp).
