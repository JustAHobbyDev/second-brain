#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

EVENTS_FILE="${REPO_ROOT}/state/pubsub/events_v0.ndjson"
OFFSETS_DIR="${REPO_ROOT}/state/pubsub/offsets"
CONSUMER=""
TOPICS=""
MAX_EVENTS="50"
NOW_TS=""

usage() {
  cat <<USAGE
Usage: $(basename "$0") --consumer <name> [options]

Options:
  --topics <csv>           Optional topic filter, comma-separated
  --max-events <int>       Max events to emit after filtering (default: 50)
  --events-file <path>     Optional event log path
  --offsets-dir <path>     Optional offsets directory
  --now-ts <RFC3339>       Optional "now" override for TTL filtering
  -h, --help               Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --consumer)
      CONSUMER="$2"; shift 2 ;;
    --topics)
      TOPICS="$2"; shift 2 ;;
    --max-events)
      MAX_EVENTS="$2"; shift 2 ;;
    --events-file)
      EVENTS_FILE="$2"; shift 2 ;;
    --offsets-dir)
      OFFSETS_DIR="$2"; shift 2 ;;
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

if [[ -z "${CONSUMER}" ]]; then
  echo "--consumer is required" >&2
  usage >&2
  exit 1
fi

if ! [[ "${MAX_EVENTS}" =~ ^[0-9]+$ ]]; then
  echo "--max-events must be a non-negative integer" >&2
  exit 1
fi

mkdir -p "$(dirname "${EVENTS_FILE}")"
mkdir -p "${OFFSETS_DIR}"
touch "${EVENTS_FILE}"

OFFSET_FILE="${OFFSETS_DIR}/${CONSUMER}.json"

python3 - "$EVENTS_FILE" "$OFFSET_FILE" "$CONSUMER" "$TOPICS" "$MAX_EVENTS" "$NOW_TS" <<'PY'
import json
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

events_file = Path(sys.argv[1])
offset_file = Path(sys.argv[2])
consumer = sys.argv[3]
topics_csv = sys.argv[4]
max_events = int(sys.argv[5])
now_ts = sys.argv[6]

topics = set()
if topics_csv.strip():
    topics = {t.strip() for t in topics_csv.split(",") if t.strip()}


def parse_rfc3339_z(value: str) -> datetime:
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    dt = datetime.fromisoformat(value)
    if dt.tzinfo is None:
        raise ValueError("timestamp must include timezone")
    return dt.astimezone(timezone.utc)


if now_ts:
    now = parse_rfc3339_z(now_ts)
else:
    now = datetime.now(timezone.utc)

next_line = 1
if offset_file.exists():
    try:
        offset_obj = json.loads(offset_file.read_text(encoding="utf-8"))
        if isinstance(offset_obj, dict) and isinstance(offset_obj.get("next_line"), int):
            next_line = max(1, offset_obj["next_line"])
    except Exception:
        next_line = 1

all_lines = events_file.read_text(encoding="utf-8").splitlines()
total_lines = len(all_lines)
start_idx = max(0, next_line - 1)
raw_slice = all_lines[start_idx:]

selected = []
for rel_idx, line in enumerate(raw_slice):
    abs_line_no = start_idx + rel_idx + 1
    if not line.strip():
        continue
    try:
        evt = json.loads(line)
    except Exception:
        continue
    if not isinstance(evt, dict):
        continue

    if topics and evt.get("topic") not in topics:
        continue

    ts = evt.get("ts")
    ttl_s = evt.get("ttl_s")
    expired = False
    try:
        evt_ts = parse_rfc3339_z(ts) if isinstance(ts, str) else None
        if evt_ts and isinstance(ttl_s, int) and ttl_s > 0:
            expired = now >= (evt_ts + timedelta(seconds=ttl_s))
    except Exception:
        expired = False

    if expired:
        continue

    evt["_line"] = abs_line_no
    selected.append(evt)
    if len(selected) >= max_events:
        break

updated_at = now.replace(microsecond=0).isoformat().replace("+00:00", "Z")
next_line_out = total_lines + 1

offset_obj = {
    "consumer": consumer,
    "events_file": str(events_file),
    "next_line": next_line_out,
    "updated_at": updated_at,
}
offset_file.write_text(json.dumps(offset_obj, indent=2, sort_keys=True) + "\n", encoding="utf-8")

result = {
    "consumer": consumer,
    "events_file": str(events_file),
    "offset_file": str(offset_file),
    "topics_filter": sorted(topics),
    "from_line": next_line,
    "to_line": total_lines,
    "next_line": next_line_out,
    "events_returned": selected,
}
print(json.dumps(result, indent=2, sort_keys=True))
PY
