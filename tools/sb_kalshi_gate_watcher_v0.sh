#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Namespace boundary declaration (spec/scene_namespace_boundary_v0.md)
TARGET_NAMESPACE="mixed"
ALLOWED_PATH_PREFIXES=("scenes/" "scene/agent/")
BOUNDARY_JUSTIFICATION="Gate watcher updates canonical gate scene plus runtime PM status mirror."

GATE_SCENE="${REPO_ROOT}/scenes/kalshi_data_gate_v0.scene.json"
PM_STATUS="${REPO_ROOT}/scene/agent/project_manager/status_v0.json"
SIGNAL_FILE=""
SIGNAL_LATEST_KALSHI_SESSION=0
USABLE_WINDOWS=""
REQUIRED_WINDOWS=""
LAST_CHECKED=""
DRY_RUN=0

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Refreshes Kalshi gate status and mirrors it into PM status.

Options:
  --signal-file <path>      Optional JSON source for gate values
  --signal-latest-kalshi-session  Auto-select most recent Kalshi session file in sessions/*/*.json
  --usable-windows <int>    Optional override for usable windows
  --required <int>          Optional override for required windows
  --last-checked <date>     Optional YYYY-MM-DD override
  --gate-scene <path>       Optional gate scene path
  --pm-status <path>        Optional PM status path
  --dry-run                 Print proposed update only
  -h, --help                Show help

Accepted signal JSON keys:
  usable_windows, required, min_windows_required, gate_passed
  current_status.{usable_windows,required}
  results.kalshi_runtime_pressure.{usable_windows,required_windows}
  thinking_trace_attachments[] entry containing:
    Gate output: {usable_windows: <n>, min_windows_required: <n>, gate_passed: <bool>, date_range: '<...>'}
  last_checked, test_date, generated_at, date_range
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --signal-file)
      SIGNAL_FILE="$2"; shift 2 ;;
    --signal-latest-kalshi-session)
      SIGNAL_LATEST_KALSHI_SESSION=1; shift ;;
    --usable-windows)
      USABLE_WINDOWS="$2"; shift 2 ;;
    --required)
      REQUIRED_WINDOWS="$2"; shift 2 ;;
    --last-checked)
      LAST_CHECKED="$2"; shift 2 ;;
    --gate-scene)
      GATE_SCENE="$2"; shift 2 ;;
    --pm-status)
      PM_STATUS="$2"; shift 2 ;;
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

python3 - "$REPO_ROOT" "$GATE_SCENE" "$PM_STATUS" "$SIGNAL_FILE" "$SIGNAL_LATEST_KALSHI_SESSION" "$USABLE_WINDOWS" "$REQUIRED_WINDOWS" "$LAST_CHECKED" "$DRY_RUN" <<'PY'
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

(
    repo_root_raw,
    gate_scene_raw,
    pm_status_raw,
    signal_file_raw,
    signal_latest_raw,
    usable_raw,
    required_raw,
    last_checked,
    dry_run_raw,
) = sys.argv[1:10]
repo_root = Path(repo_root_raw)
gate_scene = Path(gate_scene_raw)
pm_status = Path(pm_status_raw)
signal_file = Path(signal_file_raw) if signal_file_raw else None
signal_latest = signal_latest_raw == "1"
dry_run = dry_run_raw == "1"

if not gate_scene.exists():
    raise SystemExit(f"gate scene not found: {gate_scene}")
if not pm_status.exists():
    raise SystemExit(f"pm status not found: {pm_status}")
if signal_file and signal_latest:
    raise SystemExit("use either --signal-file or --signal-latest-kalshi-session, not both")
if signal_file and not signal_file.exists():
    raise SystemExit(f"signal file not found: {signal_file}")
if last_checked and not re.match(r"^\d{4}-\d{2}-\d{2}$", last_checked):
    raise SystemExit("--last-checked must be YYYY-MM-DD")


def load_json(path: Path) -> dict:
    obj = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(obj, dict):
        raise SystemExit(f"expected JSON object in {path}")
    return obj


def parse_optional_int(v: str):
    if v == "":
        return None
    if not re.match(r"^\d+$", v):
        raise SystemExit("window values must be non-negative integers")
    return int(v)


def parse_session_dt(value: str) -> Optional[datetime]:
    if not isinstance(value, str) or not value:
        return None
    try:
        if re.match(r"^\d{4}-\d{2}-\d{2}$", value):
            return datetime.strptime(value, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        value_n = value.replace("Z", "+00:00")
        parsed = datetime.fromisoformat(value_n)
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed
    except ValueError:
        return None


def infer_dt_from_name(path: Path) -> Optional[datetime]:
    m = re.match(r"^(\d{4}-\d{2}-\d{2})", path.name)
    if not m:
        return None
    return parse_session_dt(m.group(1))


if signal_latest:
    sessions_root = repo_root / "sessions"
    if not sessions_root.exists():
        raise SystemExit(f"sessions directory not found: {sessions_root}")
    best = None
    for path in sorted(sessions_root.glob("*/*.json")):
        if path.name == "index.json":
            continue
        try:
            obj = load_json(path)
        except Exception:
            continue
        links = []
        if isinstance(obj.get("project_links"), list):
            links.extend([x for x in obj["project_links"] if isinstance(x, str)])
        if isinstance(obj.get("links"), dict) and isinstance(obj["links"].get("projects"), list):
            links.extend([x for x in obj["links"]["projects"] if isinstance(x, str)])
        if not any("kalshi" in x.lower() for x in links):
            continue
        dt = parse_session_dt(obj.get("session_date")) or infer_dt_from_name(path) or datetime.fromtimestamp(0, tz=timezone.utc)
        mtime = path.stat().st_mtime
        rank = (dt.timestamp(), mtime, str(path))
        if best is None or rank > best[0]:
            best = (rank, path)
    if best is None:
        raise SystemExit("no Kalshi session artifacts found in sessions/*/*.json")
    signal_file = best[1]

gate_obj = load_json(gate_scene)
pm_obj = load_json(pm_status)
signal_obj = load_json(signal_file) if signal_file else {}
signal_runtime = {}
if isinstance(signal_obj, dict):
    candidate = signal_obj.get("results", {}).get("kalshi_runtime_pressure")
    if isinstance(candidate, dict):
        signal_runtime = candidate
signal_trace = {}
if isinstance(signal_obj, dict):
    attachments = signal_obj.get("thinking_trace_attachments")
    if isinstance(attachments, list):
        for row in attachments:
            if not isinstance(row, str) or "Gate output:" not in row:
                continue
            m_usable = re.search(r"usable_windows\\s*:\\s*(\\d+)", row)
            m_required = re.search(r"(?:min_windows_required|required_windows|required)\\s*:\\s*(\\d+)", row)
            m_passed = re.search(r"gate_passed\\s*:\\s*(true|false)", row, flags=re.IGNORECASE)
            m_range = re.search(r"date_range\\s*:\\s*'([^']+)'", row)
            if m_usable:
                signal_trace["usable_windows"] = int(m_usable.group(1))
            if m_required:
                signal_trace["required_windows"] = int(m_required.group(1))
            if m_passed:
                signal_trace["gate_passed"] = m_passed.group(1).lower() == "true"
            if m_range:
                signal_trace["date_range"] = m_range.group(1)
            break
    if not signal_trace and isinstance(signal_obj.get("summary"), str):
        # Fallback for summary line: "Data gate at 161/200 usable windows"
        m = re.search(r"\\b(\\d+)\\s*/\\s*(\\d+)\\s+usable\\s+windows\\b", signal_obj["summary"], flags=re.IGNORECASE)
        if m:
            signal_trace["usable_windows"] = int(m.group(1))
            signal_trace["required_windows"] = int(m.group(2))

current = gate_obj.get("current_status", {})
if not isinstance(current, dict):
    current = {}

usable_in = parse_optional_int(usable_raw)
required_in = parse_optional_int(required_raw)

signal_current = signal_obj.get("current_status", {}) if isinstance(signal_obj, dict) else {}
if not isinstance(signal_current, dict):
    signal_current = {}

usable = usable_in
if usable is None:
    for candidate in (
        signal_obj.get("usable_windows"),
        signal_current.get("usable_windows"),
        signal_runtime.get("usable_windows"),
        signal_trace.get("usable_windows"),
        current.get("usable_windows"),
    ):
        if isinstance(candidate, int):
            usable = candidate
            break
if usable is None:
    raise SystemExit("usable windows unavailable; pass --usable-windows or --signal-file")

required = required_in
if required is None:
    for candidate in (
        signal_obj.get("required"),
        signal_obj.get("min_windows_required"),
        signal_current.get("required"),
        signal_runtime.get("required_windows"),
        signal_trace.get("required_windows"),
        current.get("required"),
        200,
    ):
        if isinstance(candidate, int):
            required = candidate
            break

gate_passed = signal_obj.get("gate_passed")
if isinstance(signal_trace.get("gate_passed"), bool):
    ready = signal_trace["gate_passed"]
elif isinstance(gate_passed, bool):
    ready = gate_passed
else:
    ready = usable >= required

status = "READY_FOR_KALSHI_ONLY" if ready else "BLOCKED_FOR_KALSHI_ONLY"
deficit = max(required - usable, 0)

def parse_last_checked(candidate):
    if not isinstance(candidate, str) or not candidate:
        return None
    if re.match(r"^\d{4}-\d{2}-\d{2}$", candidate):
        return candidate
    if re.match(r"^\d{4}-\d{2}-\d{2}T", candidate):
        return candidate[:10]
    return None

if not last_checked:
    derived = None
    for candidate in (
        signal_obj.get("last_checked"),
        signal_current.get("last_checked"),
        signal_runtime.get("last_checked"),
        signal_obj.get("test_date"),
        signal_obj.get("generated_at"),
        signal_obj.get("timestamp"),
        signal_trace.get("last_checked"),
        current.get("last_checked"),
    ):
        derived = parse_last_checked(candidate)
        if derived:
            break

    if not derived and isinstance(signal_obj.get("date_range"), str):
        # Example: 2026-02-13T20:15:00Z -> 2026-02-15T16:30:00Z
        parts = [x.strip() for x in signal_obj["date_range"].split("->")]
        if len(parts) == 2:
            derived = parse_last_checked(parts[1])

    if not derived and isinstance(signal_runtime.get("date_range"), str):
        parts = [x.strip() for x in signal_runtime["date_range"].split("->")]
        if len(parts) == 2:
            derived = parse_last_checked(parts[1])

    if not derived and isinstance(signal_trace.get("date_range"), str):
        parts = [x.strip() for x in signal_trace["date_range"].split("->")]
        if len(parts) == 2:
            derived = parse_last_checked(parts[1])

    if not derived:
        derived = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    last_checked = derived

current["usable_windows"] = usable
current["required"] = required
current["deficit"] = deficit
current["status"] = status
current["last_checked"] = last_checked
gate_obj["current_status"] = current

now_utc = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
pm_obj["updated_at"] = now_utc
stage = pm_obj.get("stage_summary", {})
if not isinstance(stage, dict):
    stage = {}
stage["kalshi_pipeline"] = "ready_for_pipeline_progression" if ready else "blocked_for_data_windows"
stage["kalshi_blocked_state"] = {
    "required_windows": required,
    "usable_windows": usable,
    "status": status,
    "source": "scenes/kalshi_data_gate_v0.scene.json",
}
pm_obj["stage_summary"] = stage

signals = pm_obj.get("signals", {})
if not isinstance(signals, dict):
    signals = {}
signals["kalshi_window_deficit"] = deficit
signals["kalshi_gate_last_checked"] = last_checked
pm_obj["signals"] = signals

summary = {
    "usable_windows": usable,
    "required_windows": required,
    "deficit": deficit,
    "status": status,
    "last_checked": last_checked,
    "pm_stage": stage["kalshi_pipeline"],
    "gate_scene": str(gate_scene),
    "pm_status": str(pm_status),
    "signal_file": str(signal_file) if signal_file else None,
    "dry_run": dry_run,
}

if dry_run:
    print(json.dumps(summary, indent=2))
    raise SystemExit(0)

gate_scene.write_text(json.dumps(gate_obj, indent=2) + "\n", encoding="utf-8")
pm_status.write_text(json.dumps(pm_obj, indent=2) + "\n", encoding="utf-8")
print(json.dumps(summary, indent=2))
PY
