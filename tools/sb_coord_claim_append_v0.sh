#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

CLAIMS_FILE="${REPO_ROOT}/coord_claims.md"
METRICS_FILE="${REPO_ROOT}/state/coord_kpi_v0.json"
TARGET_PATH=""
ACTOR=""
TS_OVERRIDE=""

usage() {
  cat <<USAGE
Usage: $(basename "$0") --path <repo-relative-path> --actor <name> [options]

Options:
  --claims-file <path>    Optional claim file path (default: coord_claims.md)
  --metrics-file <path>   Optional metrics file path (default: state/coord_kpi_v0.json)
  --ts <RFC3339>          Optional timestamp override (UTC recommended)
  -h, --help              Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)
      TARGET_PATH="$2"; shift 2 ;;
    --actor)
      ACTOR="$2"; shift 2 ;;
    --claims-file)
      CLAIMS_FILE="$2"; shift 2 ;;
    --metrics-file)
      METRICS_FILE="$2"; shift 2 ;;
    --ts)
      TS_OVERRIDE="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage >&2
      exit 1 ;;
  esac
done

if [[ -z "${TARGET_PATH}" || -z "${ACTOR}" ]]; then
  echo "--path and --actor are required" >&2
  usage >&2
  exit 1
fi

mkdir -p "$(dirname "${CLAIMS_FILE}")"
mkdir -p "$(dirname "${METRICS_FILE}")"
touch "${CLAIMS_FILE}"

python3 - "$REPO_ROOT" "$CLAIMS_FILE" "$METRICS_FILE" "$TARGET_PATH" "$ACTOR" "$TS_OVERRIDE" <<'PY'
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

repo_root = Path(sys.argv[1]).resolve()
claims_file = Path(sys.argv[2])
metrics_file = Path(sys.argv[3])
target_path = sys.argv[4]
actor = sys.argv[5]
ts_override = sys.argv[6]

actor_re = re.compile(r"^[A-Za-z0-9._-]+$")
if not actor_re.match(actor):
    raise SystemExit("invalid --actor (allowed: A-Za-z0-9._-)")

if target_path.startswith("./"):
    raise SystemExit("invalid --path: must not start with './'")
if target_path.startswith("/"):
    raise SystemExit("invalid --path: must be repo-root-relative, not absolute")
if "\\" in target_path:
    raise SystemExit("invalid --path: use '/' separators only")

norm = str(PurePosixPath(target_path))
if norm != target_path:
    raise SystemExit("invalid --path: must be canonical repo-root-relative path")
if norm.startswith("../") or "/../" in norm or norm == "..":
    raise SystemExit("invalid --path: must not escape repo root")

abs_target = (repo_root / norm).resolve()
if repo_root not in abs_target.parents and abs_target != repo_root:
    raise SystemExit("invalid --path: escapes repo root")
if not abs_target.exists():
    raise SystemExit("invalid --path: must match an existing repository path")


def parse_ts(value: str) -> datetime:
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    dt = datetime.fromisoformat(value)
    if dt.tzinfo is None:
        raise ValueError("timestamp must include timezone")
    return dt.astimezone(timezone.utc)


if ts_override:
    ts_dt = parse_ts(ts_override)
else:
    ts_dt = datetime.now(timezone.utc)
ts = ts_dt.replace(microsecond=0).isoformat().replace("+00:00", "Z")

line = f"{norm} | {actor} | {ts}"
with claims_file.open("a", encoding="utf-8") as f:
    f.write(line + "\n")

metrics = {
    "claims_written": 0,
    "warnings_emitted": 0,
    "edits_without_claim": 0,
}
if metrics_file.exists():
    try:
        loaded = json.loads(metrics_file.read_text(encoding="utf-8"))
        if isinstance(loaded, dict):
            for k in metrics:
                if isinstance(loaded.get(k), int):
                    metrics[k] = loaded[k]
    except Exception:
        pass

metrics["claims_written"] += 1
metrics["updated_at"] = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
metrics_file.write_text(json.dumps(metrics, indent=2, sort_keys=True) + "\n", encoding="utf-8")

print(line)
PY
