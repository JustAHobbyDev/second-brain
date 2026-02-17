#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SKILLS_DIR="${REPO_ROOT}/skills"
CODEX_HOME="${CODEX_HOME:-${HOME}/.codex}"
SKILL_INSTALL_ROOT="${CODEX_HOME}/skills/local/second-brain"
JSON_OUT=0
STRICT=0

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Run a local environment and repo health check for portable second-brain usage.

Options:
  --skills-dir <path>       Repo skills directory (default: ${SKILLS_DIR})
  --codex-home <path>       Codex home directory (default: \$CODEX_HOME or ~/.codex)
  --install-root <path>     Installed skills root (default: <codex-home>/skills/local/second-brain)
  --json                    Emit JSON only
  --strict                  Return non-zero on warnings too
  -h, --help                Show help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skills-dir)
      SKILLS_DIR="$2"; shift 2 ;;
    --codex-home)
      CODEX_HOME="$2"
      SKILL_INSTALL_ROOT="${CODEX_HOME}/skills/local/second-brain"
      shift 2 ;;
    --install-root)
      SKILL_INSTALL_ROOT="$2"; shift 2 ;;
    --json)
      JSON_OUT=1; shift ;;
    --strict)
      STRICT=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage >&2
      exit 1 ;;
  esac
done

python3 - "$REPO_ROOT" "$SKILLS_DIR" "$SKILL_INSTALL_ROOT" "$JSON_OUT" "$STRICT" <<'PY'
import json
import shutil
import subprocess
import sys
from pathlib import Path

repo_root_raw, skills_dir_raw, install_root_raw, json_out_raw, strict_raw = sys.argv[1:6]
repo_root = Path(repo_root_raw).resolve()
skills_dir = Path(skills_dir_raw).resolve()
install_root = Path(install_root_raw).resolve()
json_out = json_out_raw == "1"
strict = strict_raw == "1"

checks = {"commands": [], "files": [], "skills": [], "git": []}
fail_count = 0
warn_count = 0


def add(section: str, name: str, status: str, detail: str) -> None:
    checks[section].append(
        {"name": name, "status": status, "detail": detail}
    )


for command in ("bash", "git", "jq", "python3"):
    if shutil.which(command):
        add("commands", command, "ok", "found")
    else:
        add("commands", command, "fail", "missing from PATH")
        fail_count += 1

if shutil.which("just"):
    add("commands", "just", "ok", "found")
else:
    add("commands", "just", "warn", "optional but recommended for `just sb-up`")
    warn_count += 1

required_files = [
    "scene/task_queue/v0.json",
    "scene/authority/registry_v0.json",
    "scene/ledger/mutations_v0.jsonl",
    "tools/sb_agent_run_cycle_v0.sh",
    "tools/sb_bootstrap_skills_v0.sh",
    "tools/sb_doctor_v0.sh",
]
for rel in required_files:
    path = repo_root / rel
    if path.exists():
        add("files", rel, "ok", "present")
    else:
        add("files", rel, "fail", "missing")
        fail_count += 1

if not skills_dir.exists():
    add("skills", "skills_dir", "warn", f"not found: {skills_dir}")
    warn_count += 1
    repo_skills = []
else:
    repo_skills = sorted(
        p.name for p in skills_dir.iterdir()
        if p.is_dir() and (p / "SKILL.md").exists()
    )
    if not repo_skills:
        add("skills", "skills_dir", "warn", "no local skills found")
        warn_count += 1
    else:
        add("skills", "skills_dir", "ok", f"found {len(repo_skills)} skill(s)")

for skill in repo_skills:
    install_path = install_root / skill
    if install_path.exists():
        add("skills", skill, "ok", f"installed at {install_path}")
    else:
        add("skills", skill, "warn", f"not installed at {install_path}")
        warn_count += 1

try:
    hooks = subprocess.check_output(
        ["git", "config", "--get", "core.hooksPath"],
        cwd=repo_root,
        text=True,
    ).strip()
except subprocess.CalledProcessError:
    hooks = ""

if hooks == ".githooks":
    add("git", "core.hooksPath", "ok", ".githooks")
elif hooks:
    add("git", "core.hooksPath", "warn", f"set to {hooks}, expected .githooks")
    warn_count += 1
else:
    add("git", "core.hooksPath", "warn", "unset, expected .githooks")
    warn_count += 1

overall = "ok"
if fail_count > 0:
    overall = "fail"
elif warn_count > 0:
    overall = "warn"

report = {
    "doctor_id": "second_brain_portability_doctor_v0",
    "repo_root": str(repo_root),
    "skills_dir": str(skills_dir),
    "install_root": str(install_root),
    "overall": overall,
    "fail_count": fail_count,
    "warn_count": warn_count,
    "checks": checks,
}

if json_out:
    print(json.dumps(report, indent=2))
else:
    print(f"[doctor] overall={overall} fail={fail_count} warn={warn_count}")
    for section in ("commands", "files", "skills", "git"):
        print(f"\n[{section}]")
        for item in checks[section]:
            print(f"- {item['status']:>4}  {item['name']}: {item['detail']}")

exit_code = 0
if fail_count > 0:
    exit_code = 1
elif strict and warn_count > 0:
    exit_code = 1

raise SystemExit(exit_code)
PY

