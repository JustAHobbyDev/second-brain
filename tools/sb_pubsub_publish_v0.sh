#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

EVENTS_FILE="${REPO_ROOT}/state/pubsub/events_v0.ndjson"
TOPIC=""
SCOPE=""
ACTOR=""
PAYLOAD_JSON="{}"
TTL_S="600"
IDEMPOTENCY_KEY=""
TS_OVERRIDE=""
EVENT_ID_OVERRIDE=""

usage() {
  cat <<USAGE
Usage: $(basename "$0") --topic <topic> --scope <scope> --actor <actor> [options]

Options:
  --payload-json <json>      JSON object payload (default: {})
  --ttl-s <seconds>          TTL in seconds, advisory (default: 600)
  --idempotency-key <key>    Optional explicit key
  --ts <RFC3339>             Optional timestamp override (UTC recommended)
  --event-id <id>            Optional event id override
  --events-file <path>       Optional event log path
  -h, --help                 Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --topic)
      TOPIC="$2"; shift 2 ;;
    --scope)
      SCOPE="$2"; shift 2 ;;
    --actor)
      ACTOR="$2"; shift 2 ;;
    --payload-json)
      PAYLOAD_JSON="$2"; shift 2 ;;
    --ttl-s)
      TTL_S="$2"; shift 2 ;;
    --idempotency-key)
      IDEMPOTENCY_KEY="$2"; shift 2 ;;
    --ts)
      TS_OVERRIDE="$2"; shift 2 ;;
    --event-id)
      EVENT_ID_OVERRIDE="$2"; shift 2 ;;
    --events-file)
      EVENTS_FILE="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage >&2
      exit 1 ;;
  esac
done

if [[ -z "${TOPIC}" || -z "${SCOPE}" || -z "${ACTOR}" ]]; then
  echo "--topic, --scope, and --actor are required" >&2
  usage >&2
  exit 1
fi

if ! [[ "${TTL_S}" =~ ^[0-9]+$ ]]; then
  echo "--ttl-s must be a non-negative integer" >&2
  exit 1
fi

mkdir -p "$(dirname "${EVENTS_FILE}")"

EVENT_LINE="$(
python3 - "$TOPIC" "$SCOPE" "$ACTOR" "$PAYLOAD_JSON" "$TTL_S" "$IDEMPOTENCY_KEY" "$TS_OVERRIDE" "$EVENT_ID_OVERRIDE" <<'PY'
import hashlib
import json
import re
import sys
from datetime import datetime, timezone

topic, scope, actor, payload_json, ttl_s_raw, idem_key, ts_override, event_id_override = sys.argv[1:]

try:
    payload = json.loads(payload_json)
except Exception as e:
    raise SystemExit(f"invalid --payload-json: {e}")

if not isinstance(payload, dict):
    raise SystemExit("--payload-json must decode to a JSON object")

ttl_s = int(ttl_s_raw)
if ttl_s < 0:
    raise SystemExit("--ttl-s must be >= 0")


def parse_rfc3339_z(value: str) -> datetime:
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    dt = datetime.fromisoformat(value)
    if dt.tzinfo is None:
        raise ValueError("timestamp must include timezone")
    return dt.astimezone(timezone.utc)


ts_dt = parse_rfc3339_z(ts_override) if ts_override else datetime.now(timezone.utc)
ts = ts_dt.replace(microsecond=0).isoformat().replace("+00:00", "Z")

if event_id_override:
    event_id = event_id_override
else:
    stamp = ts_dt.strftime("%Y%m%dT%H%M%SZ")
    seed = f"{topic}|{scope}|{actor}|{ts}|{json.dumps(payload, sort_keys=True, separators=(',', ':'))}"
    digest = hashlib.sha256(seed.encode("utf-8")).hexdigest()[:12]
    event_id = f"evt_{stamp}_{digest}"

if idem_key:
    idempotency_key = idem_key
else:
    idempotency_key = f"{topic}|{scope}|{actor}|{ts}"

event = {
    "event_id": event_id,
    "ts": ts,
    "topic": topic,
    "scope": scope,
    "actor": actor,
    "payload": payload,
    "ttl_s": ttl_s,
    "idempotency_key": idempotency_key,
}

print(json.dumps(event, sort_keys=True, separators=(",", ":")))
PY
)"

printf '%s\n' "${EVENT_LINE}" >> "${EVENTS_FILE}"
echo "${EVENT_LINE}"
