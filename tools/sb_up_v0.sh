#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MODE="symlink"
FORCE=0
SKILLS_DIR="${REPO_ROOT}/skills"
CODEX_HOME="${CODEX_HOME:-${HOME}/.codex}"
INSTALL_ROOT="${CODEX_HOME}/skills/local/second-brain"
STRICT=0
DRY_RUN=0

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Portable startup entrypoint:
1) bootstrap project-local skills into Codex skill path
2) run second-brain doctor checks

Options:
  --mode <symlink|copy>     Skill install mode for bootstrap (default: symlink)
  --force                   Replace existing installed skill paths
  --skills-dir <path>       Repo skills directory override
  --codex-home <path>       Codex home override
  --install-root <path>     Installed skills root override
  --strict                  Fail if doctor reports warnings
  --dry-run                 Show plan only
  -h, --help                Show help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="$2"; shift 2 ;;
    --force)
      FORCE=1; shift ;;
    --skills-dir)
      SKILLS_DIR="$2"; shift 2 ;;
    --codex-home)
      CODEX_HOME="$2"
      INSTALL_ROOT="${CODEX_HOME}/skills/local/second-brain"
      shift 2 ;;
    --install-root)
      INSTALL_ROOT="$2"; shift 2 ;;
    --strict)
      STRICT=1; shift ;;
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

BOOTSTRAP_ARGS=(--mode "${MODE}" --skills-dir "${SKILLS_DIR}" --dest-root "${INSTALL_ROOT}")
if [[ "${FORCE}" -eq 1 ]]; then
  BOOTSTRAP_ARGS+=(--force)
fi
if [[ "${DRY_RUN}" -eq 1 ]]; then
  BOOTSTRAP_ARGS+=(--dry-run)
fi

DOCTOR_ARGS=(--skills-dir "${SKILLS_DIR}" --install-root "${INSTALL_ROOT}")
if [[ "${STRICT}" -eq 1 ]]; then
  DOCTOR_ARGS+=(--strict)
fi
if [[ "${DRY_RUN}" -eq 1 ]]; then
  DOCTOR_ARGS+=(--json)
fi

echo "[sb-up] bootstrap skills"
"${REPO_ROOT}/tools/sb_bootstrap_skills_v0.sh" "${BOOTSTRAP_ARGS[@]}"

echo
echo "[sb-up] run doctor"
"${REPO_ROOT}/tools/sb_doctor_v0.sh" "${DOCTOR_ARGS[@]}"

if [[ "${DRY_RUN}" -eq 0 ]]; then
  echo
  echo "[sb-up] complete"
  echo "- Skills installed at: ${INSTALL_ROOT}"
  echo "- Run 'tools/sb_doctor_v0.sh --json' for machine-readable diagnostics"
fi

