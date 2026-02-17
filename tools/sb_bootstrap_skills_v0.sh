#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SKILLS_DIR="${REPO_ROOT}/skills"
CODEX_HOME="${CODEX_HOME:-${HOME}/.codex}"
DEST_ROOT="${CODEX_HOME}/skills/local/second-brain"
MODE="symlink"
FORCE=0
DRY_RUN=0

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Install project-local skills into Codex skill discovery path.

Options:
  --mode <symlink|copy>     Install mode (default: symlink)
  --skills-dir <path>       Repo skills directory (default: ${SKILLS_DIR})
  --codex-home <path>       Codex home directory (default: \$CODEX_HOME or ~/.codex)
  --dest-root <path>        Destination skills root (default: <codex-home>/skills/local/second-brain)
  --force                   Replace existing destination skill paths
  --dry-run                 Print planned actions only
  -h, --help                Show help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="$2"; shift 2 ;;
    --skills-dir)
      SKILLS_DIR="$2"; shift 2 ;;
    --codex-home)
      CODEX_HOME="$2"
      DEST_ROOT="${CODEX_HOME}/skills/local/second-brain"
      shift 2 ;;
    --dest-root)
      DEST_ROOT="$2"; shift 2 ;;
    --force)
      FORCE=1; shift ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage >&2
      exit 1 ;;
  esac
done

if [[ "${MODE}" != "symlink" && "${MODE}" != "copy" ]]; then
  echo "--mode must be one of: symlink, copy" >&2
  exit 1
fi

python3 - "$SKILLS_DIR" "$DEST_ROOT" "$MODE" "$FORCE" "$DRY_RUN" <<'PY'
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

skills_dir_raw, dest_root_raw, mode, force_raw, dry_run_raw = sys.argv[1:6]
skills_dir = Path(skills_dir_raw).resolve()
dest_root = Path(dest_root_raw).resolve()
force = force_raw == "1"
dry_run = dry_run_raw == "1"

if not skills_dir.exists() or not skills_dir.is_dir():
    raise SystemExit(f"skills dir not found: {skills_dir}")

skills = sorted(
    p for p in skills_dir.iterdir()
    if p.is_dir() and (p / "SKILL.md").exists()
)
if not skills:
    raise SystemExit(f"no skills found under: {skills_dir}")

actions = []
for src in skills:
    dst = dest_root / src.name
    action = {"skill": src.name, "source": str(src), "destination": str(dst), "operation": "noop"}
    if not dst.exists():
        action["operation"] = "install"
    elif mode == "symlink" and dst.is_symlink() and dst.resolve() == src.resolve():
        action["operation"] = "noop"
    elif force:
        action["operation"] = "replace"
    else:
        raise SystemExit(
            f"destination exists and differs for skill '{src.name}': {dst}\n"
            f"Re-run with --force to replace."
        )
    actions.append(action)

manifest = {
    "manifest_id": "second_brain_skill_bootstrap_v0",
    "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "mode": mode,
    "skills_dir": str(skills_dir),
    "dest_root": str(dest_root),
    "skills": [a["skill"] for a in actions],
}

if dry_run:
    print(json.dumps({"dry_run": True, "actions": actions, "manifest": manifest}, indent=2))
    raise SystemExit(0)

dest_root.mkdir(parents=True, exist_ok=True)
for action in actions:
    src = Path(action["source"])
    dst = Path(action["destination"])
    if action["operation"] in {"replace"} and dst.exists():
        if dst.is_symlink() or dst.is_file():
            dst.unlink()
        else:
            shutil.rmtree(dst)
    if action["operation"] in {"install", "replace"}:
        if mode == "symlink":
            dst.symlink_to(src, target_is_directory=True)
        else:
            shutil.copytree(src, dst)

manifest_path = dest_root / "_bootstrap_manifest_v0.json"
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"dry_run": False, "actions": actions, "manifest_path": str(manifest_path)}, indent=2))
PY

