#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

CLAIMS_FILE="${REPO_ROOT}/coord_claims.md"
METRICS_FILE="${REPO_ROOT}/state/coord_kpi_v0.json"
TARGET_PATH=""
ACTOR=""
TTL_S="600"
WINDOW_LINES="200"
MODE="edit"
NOW_TS=""

usage() {
  cat <<USAGE
Usage: $(basename "$0") --path <repo-relative-path> --actor <name> [options]

Options:
  --claims-file <path>    Optional claim file path (default: coord_claims.md)
  --metrics-file <path>   Optional metrics file path (default: state/coord_kpi_v0.json)
  --ttl-s <seconds>       Active-claim ttl (default: 600)
  --window-lines <n>      Number of trailing lines to inspect (default: 200)
  --mode <edit|claim>     edit checks active claim by actor (default: edit)
  --now-ts <RFC3339>      Optional current timestamp override
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
    --ttl-s)
      TTL_S="$2"; shift 2 ;;
    --window-lines)
      WINDOW_LINES="$2"; shift 2 ;;
    --mode)
      MODE="$2"; shift 2 ;;
    --now-ts)
      NOW_TS="$2"; shift 2 ;;
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

if ! [[ "${TTL_S}" =~ ^[0-9]+$ ]]; then
  echo "--ttl-s must be a non-negative integer" >&2
  exit 1
fi

if ! [[ "${WINDOW_LINES}" =~ ^[0-9]+$ ]]; then
  echo "--window-lines must be a non-negative integer" >&2
  exit 1
fi

if [[ "${MODE}" != "edit" && "${MODE}" != "claim" ]]; then
  echo "--mode must be edit or claim" >&2
  exit 1
fi

mkdir -p "$(dirname "${CLAIMS_FILE}")"
mkdir -p "$(dirname "${METRICS_FILE}")"
touch "${CLAIMS_FILE}"

python3 - "$REPO_ROOT" "$CLAIMS_FILE" "$METRICS_FILE" "$TARGET_PATH" "$ACTOR" "$TTL_S" "$WINDOW_LINES" "$MODE" "$NOW_TS" <<'PY'
import json
import re
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path, PurePosixPath

repo_root = Path(sys.argv[1]).resolve()
claims_file = Path(sys.argv[2])
metrics_file = Path(sys.argv[3])
target_path = sys.argv[4]
actor = sys.argv[5]
ttl_s = int(sys.argv[6])
window_lines = int(sys.argv[7])
mode = sys.argv[8]
now_ts = sys.argv[9]

claim_re = re.compile(r"^([^|]+) \| ([A-Za-z0-9._-]+) \| (\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)$")
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


now = parse_ts(now_ts) if now_ts else datetime.now(timezone.utc)
lines = claims_file.read_text(encoding="utf-8").splitlines()
tail = lines[-window_lines:] if window_lines > 0 else []

warnings = []
has_active_claim_for_actor = False
has_conflict = False

for idx, raw in enumerate(tail, start=max(1, len(lines) - len(tail) + 1)):
    if not raw.strip():
        continue
    m = claim_re.match(raw.strip())
    if not m:
        warnings.append(f"malformed claim line at {idx}: {raw}")
        continue
    p, claim_actor, ts = m.groups()
    try:
        claim_ts = parse_ts(ts)
    except Exception:
        warnings.append(f"invalid timestamp at {idx}: {raw}")
        continue
    age = now - claim_ts
    active = age < timedelta(seconds=ttl_s)
    if not active:
        continue
    if p != norm:
        continue
    if claim_actor == actor:
        has_active_claim_for_actor = True
    else:
        has_conflict = True
        warnings.append(
            f"active conflicting claim on {norm}: actor={claim_actor}, age_s={int(age.total_seconds())}"
        )

edits_without_claim = 0
if mode == "edit" and not has_active_claim_for_actor:
    warnings.append(f"edit requested without active claim for {norm} by {actor}")
    edits_without_claim = 1

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

metrics["warnings_emitted"] += len(warnings)
metrics["edits_without_claim"] += edits_without_claim
metrics["updated_at"] = now.replace(microsecond=0).isoformat().replace("+00:00", "Z")
metrics_file.write_text(json.dumps(metrics, indent=2, sort_keys=True) + "\n", encoding="utf-8")

for w in warnings:
    print(f"warning: {w}", file=sys.stderr)

out = {
    "path": norm,
    "actor": actor,
    "mode": mode,
    "window_lines_scanned": len(tail),
    "has_active_claim_for_actor": has_active_claim_for_actor,
    "conflict_detected": has_conflict,
    "warnings_count": len(warnings),
}
print(json.dumps(out, sort_keys=True))
PY
