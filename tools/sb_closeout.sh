#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TOOL=""
INPUT=""
SESSIONS_DIR="${REPO_ROOT}/sessions"
UPDATE_INDEX=1
ALLOW_SPARSE_LINKS=0
ALLOW_UNKNOWN_IDS=0
SUGGEST_SCENES=1

usage() {
  cat <<USAGE
Usage: $(basename "$0") --tool <name> [--input <json-file>] [--sessions-dir <path>] [--no-index] [--allow-sparse-links] [--allow-unknown-ids] [--no-scene-suggest]

Reads closeout JSON (from --input or stdin), validates against v1 ritual contract, writes to:
  sessions/<tool>/YYYY-MM-DD-<slug>.json

Default behavior:
  - Auto-updates sessions/<tool>/index.json
  - Suggests scene fold-in targets based on link overlap
  - Resolves project aliases from scenes/project_id_alias_map.scene.json when present

Options:
  --tool <name>          Tool/LLM folder name (e.g. codex, claude, chatgpt).
  --input <json-file>    Optional input file. If omitted, reads JSON from stdin.
  --sessions-dir <path>  Optional sessions root override.
  --no-index             Skip index update.
  --allow-sparse-links   Relax minimum link density checks.
  --allow-unknown-ids    Skip canonical-ID existence checks against scenes.
  --no-scene-suggest     Disable scene fold-in suggestions.
  -h, --help             Show help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tool)
      TOOL="$2"
      shift 2
      ;;
    --input)
      INPUT="$2"
      shift 2
      ;;
    --sessions-dir)
      SESSIONS_DIR="$2"
      shift 2
      ;;
    --no-index)
      UPDATE_INDEX=0
      shift
      ;;
    --allow-sparse-links)
      ALLOW_SPARSE_LINKS=1
      shift
      ;;
    --allow-unknown-ids)
      ALLOW_UNKNOWN_IDS=1
      shift
      ;;
    --no-scene-suggest)
      SUGGEST_SCENES=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${TOOL}" ]]; then
  echo "--tool is required" >&2
  usage >&2
  exit 1
fi

if [[ -n "${INPUT}" && ! -f "${INPUT}" ]]; then
  echo "Input file does not exist: ${INPUT}" >&2
  exit 1
fi

mkdir -p "${SESSIONS_DIR}/${TOOL}"

if [[ -n "${INPUT}" ]]; then
  JSON_PAYLOAD="$(cat "${INPUT}")"
else
  JSON_PAYLOAD="$(cat)"
fi

if [[ -z "${JSON_PAYLOAD}" ]]; then
  echo "No JSON payload provided" >&2
  exit 1
fi

TMP_INPUT="$(mktemp)"
trap 'rm -f "${TMP_INPUT}"' EXIT
printf "%s" "${JSON_PAYLOAD}" > "${TMP_INPUT}"

python3 - "$TOOL" "$SESSIONS_DIR" "$UPDATE_INDEX" "$ALLOW_SPARSE_LINKS" "$ALLOW_UNKNOWN_IDS" "$SUGGEST_SCENES" "$REPO_ROOT" "$TMP_INPUT" <<'PY'
import json
import os
import re
import sys
from collections import Counter
from datetime import datetime, timezone


def die(msg: str) -> None:
    print(f"error: {msg}", file=sys.stderr)
    raise SystemExit(1)


def uniq_keep_order(xs):
    out = []
    seen = set()
    for x in xs:
        if x not in seen:
            seen.add(x)
            out.append(x)
    return out


def load_scene_catalog(repo_root: str):
    scenes_dir = os.path.join(repo_root, "scenes")
    project_ids = set()
    principle_ids = set()
    pattern_ids = set()
    scene_refs = []
    if not os.path.isdir(scenes_dir):
        return project_ids, principle_ids, pattern_ids, scene_refs

    for name in sorted(os.listdir(scenes_dir)):
        if not name.endswith(".scene.json"):
            continue
        path = os.path.join(scenes_dir, name)
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception:
            continue
        nodes = data.get("nodes") if isinstance(data, dict) else None
        edges = data.get("edges") if isinstance(data, dict) else None
        node_ids = set()
        if isinstance(nodes, list):
            for n in nodes:
                if isinstance(n, dict):
                    nid = n.get("id")
                    if isinstance(nid, str):
                        node_ids.add(nid)
                        if nid.startswith("project/"):
                            project_ids.add(nid)
                        elif nid.startswith("principle/"):
                            principle_ids.add(nid)
                        elif nid.startswith("pattern/"):
                            pattern_ids.add(nid)
        edge_endpoints = set()
        if isinstance(edges, list):
            for e in edges:
                if isinstance(e, dict):
                    for k in ("from", "to"):
                        v = e.get(k)
                        if isinstance(v, str):
                            edge_endpoints.add(v)
        scene_refs.append((name, node_ids, edge_endpoints))

    return project_ids, principle_ids, pattern_ids, scene_refs


def load_project_aliases(repo_root: str):
    alias_path = os.path.join(repo_root, "scenes", "project_id_alias_map.scene.json")
    aliases = {}
    if not os.path.isfile(alias_path):
        return aliases
    try:
        with open(alias_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        return aliases
    nodes = data.get("nodes") if isinstance(data, dict) else None
    if not isinstance(nodes, list):
        return aliases
    for n in nodes:
        if not isinstance(n, dict):
            continue
        mapping = n.get("mapping")
        if isinstance(mapping, dict):
            src = mapping.get("from")
            dst = mapping.get("to")
            if isinstance(src, str) and isinstance(dst, str):
                aliases[src] = dst
    return aliases


def suggest_scenes(scene_refs, target_ids):
    c = Counter()
    for name, node_ids, edge_endpoints in scene_refs:
        score = 0
        for tid in target_ids:
            if tid in node_ids:
                score += 2
            if tid in edge_endpoints:
                score += 1
        if score:
            c[name] = score
    return [name for name, _ in c.most_common(8)]


tool = sys.argv[1]
sessions_dir = sys.argv[2]
update_index = sys.argv[3] == "1"
allow_sparse_links = sys.argv[4] == "1"
allow_unknown_ids = sys.argv[5] == "1"
do_suggest_scenes = sys.argv[6] == "1"
repo_root = sys.argv[7]
input_path = sys.argv[8]

try:
    with open(input_path, "r", encoding="utf-8") as f:
        raw = f.read()
except Exception as e:
    die(f"failed to read input payload: {e}")
if not raw.strip():
    die("empty input JSON")

try:
    data = json.loads(raw)
except Exception as e:
    die(f"invalid JSON: {e}")

if not isinstance(data, dict):
    die("top-level JSON must be an object")

required_keys = {
    "artifact_id",
    "session_date",
    "llm_used",
    "project_links",
    "principle_links",
    "pattern_links",
    "tool_links",
    "related_artifact_links",
    "summary",
    "key_decisions",
    "open_questions",
    "next_steps",
    "thinking_trace_attachments",
    "prompt_lineage",
    "resumption_score",
    "resumption_notes",
}

extra = set(data.keys()) - required_keys
missing = required_keys - set(data.keys())
if missing:
    die(f"missing required keys: {sorted(missing)}")
if extra:
    die(f"unexpected top-level keys: {sorted(extra)}")

artifact_id = data["artifact_id"]
if not isinstance(artifact_id, str):
    die("artifact_id must be a string")

m = re.match(r"^artifact/([a-z0-9]+)_([0-9]{4})_([0-9]{2})_([0-9]{2})_([a-z0-9]+(?:-[a-z0-9]+){2,5})$", artifact_id)
if not m:
    die("artifact_id must match artifact/{llm}_{YYYY_MM_DD}_{kebab-case-3-to-6-word-slug}")

llm_from_id, yyyy, mm, dd, slug = m.groups()

llm_used = data["llm_used"]
if not isinstance(llm_used, str) or not llm_used:
    die("llm_used must be a non-empty string")
if llm_used.lower() != llm_from_id:
    die("llm_used must match artifact_id llm prefix")
if tool.lower() != llm_from_id:
    die("--tool must match artifact_id llm prefix")

session_date = data["session_date"]
if not isinstance(session_date, str) or not re.match(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$", session_date):
    die("session_date must be YYYY-MM-DD")
if session_date != f"{yyyy}-{mm}-{dd}":
    die("session_date must match artifact_id date")

if not isinstance(data["summary"], str) or not data["summary"].strip():
    die("summary must be a non-empty string")
if not isinstance(data["resumption_notes"], str) or not data["resumption_notes"].strip():
    die("resumption_notes must be a non-empty string")

score = data["resumption_score"]
if not isinstance(score, int) or score < 0 or score > 10:
    die("resumption_score must be an integer between 0 and 10")
if score < 6:
    die("resumption_score must be >= 6 for passing closeout")

id_re = re.compile(r"^[a-z_]+/[A-Za-z0-9._:-]+$")

def validate_id_list(name: str, value, min_count: int | None = None) -> None:
    if not isinstance(value, list):
        die(f"{name} must be an array")
    if min_count is not None and len(value) < min_count:
        die(f"{name} must contain at least {min_count} item(s)")
    for i, item in enumerate(value):
        if not isinstance(item, str):
            die(f"{name}[{i}] must be a string")
        if not id_re.match(item):
            die(f"{name}[{i}] is not canonical type/identifier: {item}")

validate_id_list("project_links", data["project_links"], 1)
if allow_sparse_links:
    validate_id_list("principle_links", data["principle_links"])
    validate_id_list("pattern_links", data["pattern_links"])
else:
    validate_id_list("principle_links", data["principle_links"], 2)
    validate_id_list("pattern_links", data["pattern_links"], 1)
validate_id_list("tool_links", data["tool_links"], 1)
validate_id_list("related_artifact_links", data["related_artifact_links"])

aliases = load_project_aliases(repo_root)
if aliases:
    data["project_links"] = uniq_keep_order([aliases.get(p, p) for p in data["project_links"]])

projects, principles, patterns, scene_refs = load_scene_catalog(repo_root)
if not allow_unknown_ids:
    missing_projects = [x for x in data["project_links"] if x not in projects]
    missing_principles = [x for x in data["principle_links"] if x not in principles]
    missing_patterns = [x for x in data["pattern_links"] if x not in patterns]
    if missing_projects:
        die(f"non-canonical project_links (not found in scenes): {missing_projects}")
    if missing_principles:
        die(f"non-canonical principle_links (not found in scenes): {missing_principles}")
    if missing_patterns:
        die(f"non-canonical pattern_links (not found in scenes): {missing_patterns}")

for arr_name in ["key_decisions", "next_steps", "thinking_trace_attachments"]:
    arr = data[arr_name]
    if not isinstance(arr, list):
        die(f"{arr_name} must be an array")
    for i, item in enumerate(arr):
        if not isinstance(item, str) or not item.strip():
            die(f"{arr_name}[{i}] must be a non-empty string")

open_q = data["open_questions"]
if not isinstance(open_q, list):
    die("open_questions must be an array")
for i, q in enumerate(open_q):
    if not isinstance(q, str) or not q.strip():
        die(f"open_questions[{i}] must be a non-empty string")
    if not re.match(r"^[0-9]+\.\s", q):
        die(f"open_questions[{i}] must be numbered and actionable")

lineage = data["prompt_lineage"]
if not isinstance(lineage, list) or not lineage:
    die("prompt_lineage must be a non-empty array")
for i, item in enumerate(lineage):
    if not isinstance(item, dict):
        die(f"prompt_lineage[{i}] must be an object")
    role = item.get("role")
    if not isinstance(role, str) or not role:
        die(f"prompt_lineage[{i}].role must be a non-empty string")
    ref = item.get("ref")
    summary = item.get("summary")
    if not ((isinstance(ref, str) and ref.strip()) or (isinstance(summary, str) and summary.strip())):
        die(f"prompt_lineage[{i}] must include ref or summary")

out_dir = os.path.join(sessions_dir, tool)
os.makedirs(out_dir, exist_ok=True)
out_name = f"{session_date}-{slug}.json"
out_path = os.path.join(out_dir, out_name)
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

index_path = os.path.join(out_dir, "index.json")

if update_index:
    records = []
    for name in sorted(os.listdir(out_dir)):
        if not name.endswith(".json") or name == "index.json":
            continue
        p = os.path.join(out_dir, name)
        try:
            with open(p, "r", encoding="utf-8") as f:
                obj = json.load(f)
        except Exception:
            continue
        if not isinstance(obj, dict):
            continue

        aid = obj.get("artifact_id") or obj.get("id")
        if not isinstance(aid, str):
            continue

        date = obj.get("session_date")
        if not isinstance(date, str):
            mm = re.search(r"([0-9]{4})_([0-9]{2})_([0-9]{2})", aid)
            date = f"{mm.group(1)}-{mm.group(2)}-{mm.group(3)}" if mm else ""

        resumption = obj.get("resumption_score")
        if not isinstance(resumption, int):
            resumption = None

        summary = obj.get("summary")
        summary_snippet = ""
        if isinstance(summary, str):
            summary_snippet = summary.strip()
        elif isinstance(summary, dict):
            hl = summary.get("high_level")
            if isinstance(hl, str):
                summary_snippet = hl.strip()
        if len(summary_snippet) > 160:
            summary_snippet = summary_snippet[:157] + "..."

        records.append(
            {
                "id": aid,
                "date": date,
                "resumption_score": resumption,
                "summary_snippet": summary_snippet,
            }
        )

    by_id = {r["id"]: r for r in records}
    artifacts = sorted(by_id.values(), key=lambda r: (r.get("date") or "", r["id"]))
    index_obj = {
        "tool": tool,
        "artifacts": artifacts,
        "last_updated": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    }
    with open(index_path, "w", encoding="utf-8") as f:
        json.dump(index_obj, f, indent=2)
        f.write("\n")

print(out_path)
if update_index:
    print(index_path)

if do_suggest_scenes:
    target_ids = uniq_keep_order(data["project_links"] + data["principle_links"] + data["pattern_links"])
    suggestions = suggest_scenes(scene_refs, target_ids)
    print("SCENE_SUGGESTIONS=" + json.dumps(suggestions))
PY
