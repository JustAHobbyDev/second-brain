#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

staged_names_all="$(git diff --cached --name-only)"
if [[ -z "$staged_names_all" ]]; then
  exit 0
fi

staged_names="$(git diff --cached --name-only -- . ':(exclude)reports/checkpoints/*')"
if [[ -z "$staged_names" ]]; then
  staged_names="$staged_names_all"
fi

ts_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ts_compact="$(date -u +%Y%m%dT%H%M%SZ)"
branch="$(git rev-parse --abbrev-ref HEAD)"
head_short="$(git rev-parse --short HEAD 2>/dev/null || echo "none")"

mkdir -p reports/checkpoints

slug_input="$staged_names"

mapfile -t slug_parts < <(
  printf '%s\n' "$slug_input" \
    | sed -E 's#^.*/##; s/\.[^.]+$//; s/[^A-Za-z0-9]+/-/g; s/^-+|-+$//g' \
    | tr 'A-Z' 'a-z' \
    | awk 'length > 0' \
    | awk '!seen[$0]++' \
    | head -n 3
)
work_slug="$(IFS=-; echo "${slug_parts[*]}")"
if [[ -z "$work_slug" ]]; then
  work_slug="workspace-update"
fi

report_file="reports/checkpoints/${ts_compact}_${work_slug}_checkpoint.md"
latest_file="reports/checkpoints/LATEST.md"
index_file="reports/checkpoints/index.jsonl"

numstat="$(git diff --cached --numstat -- . ':(exclude)reports/checkpoints/*')"
if [[ -z "$numstat" ]]; then
  numstat="$(git diff --cached --numstat)"
fi
files_changed="$(printf '%s\n' "$numstat" | sed '/^$/d' | wc -l | tr -d ' ')"
insertions="$(printf '%s\n' "$numstat" | awk '{if ($1 ~ /^[0-9]+$/) s+=$1} END {print s+0}')"
deletions="$(printf '%s\n' "$numstat" | awk '{if ($2 ~ /^[0-9]+$/) s+=$2} END {print s+0}')"

staged_name_status="$(git diff --cached --name-status -- . ':(exclude)reports/checkpoints/*')"
if [[ -z "$staged_name_status" ]]; then
  staged_name_status="$(git diff --cached --name-status)"
fi

staged_diffstat="$(git diff --cached --stat -- . ':(exclude)reports/checkpoints/*')"
if [[ -z "$staged_diffstat" ]]; then
  staged_diffstat="$(git diff --cached --stat)"
fi

cat > "$report_file" <<EOF
# Pre-Commit Checkpoint

- timestamp_utc: $ts_iso
- branch: $branch
- head_before_commit: $head_short
- work_slug: $work_slug
- files_changed: $files_changed
- insertions: $insertions
- deletions: $deletions

## Staged Files

\`\`\`text
$staged_name_status
\`\`\`

## Diffstat

\`\`\`text
$staged_diffstat
\`\`\`
EOF

cp "$report_file" "$latest_file"

printf '{"timestamp":"%s","branch":"%s","head_before_commit":"%s","report_path":"%s","files_changed":%s,"insertions":%s,"deletions":%s}\n' \
  "$ts_iso" "$branch" "$head_short" "$report_file" "$files_changed" "$insertions" "$deletions" >> "$index_file"

git add "$report_file" "$latest_file" "$index_file"
