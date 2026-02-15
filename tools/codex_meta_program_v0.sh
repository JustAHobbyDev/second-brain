#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROMPT_DIR="${REPO_ROOT}/prompts/meta_program"

PROMPTS=(
  "00_context.txt"
  "10_generate_project_history_spec.txt"
  "20_phase_model_and_schema.txt"
  "30_closeout_template_integration.txt"
  "40_cognitive_profile_spec.txt"
  "50_agent_owned_audit.txt"
)

if [[ "${HYPERFAST_MODE:-false}" == "true" ]]; then
  PROMPTS+=("60_hyperfast_mode_route.txt")
fi

usage() {
  cat <<'EOF'
Usage:
  tools/codex_meta_program_v0.sh [--] [LLM_COMMAND...]

Behavior:
  - Runs prompts/meta_program/*.txt in deterministic order.
  - Pipes each prompt file to the provided LLM command via stdin.
  - If HYPERFAST_MODE=true, appends hyperfast route prompt:
      prompts/meta_program/60_hyperfast_mode_route.txt
  - If no command is provided:
      1) Uses LLM_CMD env var if set (executed via: bash -lc "$LLM_CMD")
      2) Falls back to: codex exec

Examples:
  tools/codex_meta_program_v0.sh -- codex exec
  tools/codex_meta_program_v0.sh -- your-llm-cli run --stdin
  LLM_CMD='codex exec' tools/codex_meta_program_v0.sh
  HYPERFAST_MODE=true tools/codex_meta_program_v0.sh -- codex exec
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "${1:-}" == "--" ]]; then
  shift
fi

if [[ "$#" -gt 0 ]]; then
  RUN_CMD=("$@")
  RUN_DESC="${RUN_CMD[*]}"
elif [[ -n "${LLM_CMD:-}" ]]; then
  RUN_CMD=(bash -lc "${LLM_CMD}")
  RUN_DESC="${LLM_CMD}"
else
  RUN_CMD=(codex exec)
  RUN_DESC="codex exec"
fi

cd "${REPO_ROOT}"

for prompt in "${PROMPTS[@]}"; do
  prompt_path="${PROMPT_DIR}/${prompt}"
  if [[ ! -f "${prompt_path}" ]]; then
    echo "Missing prompt file: ${prompt_path}" >&2
    exit 1
  fi

  echo "Running ${prompt_path} with: ${RUN_DESC}"
  cat "${prompt_path}" | "${RUN_CMD[@]}"
done

echo "Done. Review git diff, then commit."
