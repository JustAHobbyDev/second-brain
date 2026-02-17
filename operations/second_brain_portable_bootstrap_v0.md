# Second Brain Portable Bootstrap v0

## Purpose

Make `project/second-brain` runnable from any machine with deterministic startup checks.

## Scope

- Install repo-local skills into Codex skill discovery path.
- Verify local command/file/runtime prerequisites.
- Keep process local-only (no network calls, no remote state mutation).

## One-Command Startup

From repo root:

```bash
./tools/sb_up_v0.sh
```

Or with `just`:

```bash
just sb-up
```

## Startup Sequence (deterministic)

1) `tools/sb_bootstrap_skills_v0.sh`

- Discovers local skills under `skills/*/SKILL.md`.
- Installs to `${CODEX_HOME:-~/.codex}/skills/local/second-brain` (or override path).
- Supports `--mode symlink` (default) and `--mode copy`.

2) `tools/sb_doctor_v0.sh`

- Checks required commands: `bash`, `git`, `jq`, `python3` (and warns on missing `just`).
- Checks core repo files required for agent workflows.
- Checks whether local skills are installed.
- Checks `git config core.hooksPath` status.

## Common Flags

```bash
./tools/sb_up_v0.sh --dry-run
./tools/sb_up_v0.sh --mode copy --force
./tools/sb_up_v0.sh --strict
./tools/sb_doctor_v0.sh --json
```

## Recommended First-Time Setup

```bash
git config core.hooksPath .githooks
./tools/sb_up_v0.sh --mode symlink
```

## Notes

- `--mode symlink` keeps installed skills synced to repo edits.
- `--mode copy` is useful when symlinks are constrained by environment policy.
- `--force` replaces existing installed skill paths under the configured install root only.
