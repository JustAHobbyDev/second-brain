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
)

cd "${REPO_ROOT}"

for prompt in "${PROMPTS[@]}"; do
  prompt_path="${PROMPT_DIR}/${prompt}"
  if [[ ! -f "${prompt_path}" ]]; then
    echo "Missing prompt file: ${prompt_path}" >&2
    exit 1
  fi

  echo "Running ${prompt_path}"
  cat "${prompt_path}" | codex exec
done

echo "Done. Review git diff, then commit."
