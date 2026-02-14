#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SCENE_INPUT=""
GRAPH_PATH="${REPO_ROOT}/graph/graph.json"
MODE="dry_run"

usage() {
  cat <<USAGE
Usage: $(basename "$0") --scene <file-or-dir> [--graph <path>] [--mode apply|dry_run]

Options:
  --scene   Required scene file or directory path.
  --graph   Optional graph output path (default: graph/graph.json).
  --mode    dry_run (default) or apply.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scene)
      SCENE_INPUT="$2"
      shift 2
      ;;
    --graph)
      GRAPH_PATH="$2"
      shift 2
      ;;
    --mode)
      MODE="$2"
      shift 2
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

if [[ -z "${SCENE_INPUT}" ]]; then
  echo "--scene is required" >&2
  usage >&2
  exit 1
fi

if [[ "${MODE}" != "apply" && "${MODE}" != "dry_run" ]]; then
  echo "--mode must be apply or dry_run" >&2
  exit 1
fi

if [[ ! -e "${SCENE_INPUT}" ]]; then
  echo "Scene input does not exist: ${SCENE_INPUT}" >&2
  exit 1
fi

mkdir -p "$(dirname "${GRAPH_PATH}")"
if [[ "${MODE}" == "apply" && ! -f "${GRAPH_PATH}" ]]; then
  printf '{\n  "nodes": [],\n  "edges": []\n}\n' > "${GRAPH_PATH}"
fi

python3 - "$REPO_ROOT" "$SCENE_INPUT" "$GRAPH_PATH" "$MODE" <<'PY'
import json
import os
import sys
from typing import Any

repo_root, scene_input, graph_path, mode = sys.argv[1:]


def die(msg: str) -> None:
    print(f"error: {msg}", file=sys.stderr)
    raise SystemExit(1)


def normalize_path(p: str) -> str:
    abs_path = os.path.abspath(p)
    return os.path.relpath(abs_path, repo_root)


def scene_stem(scene_rel: str) -> str:
    base = os.path.basename(scene_rel)
    if base.endswith(".scene.json"):
        return base[: -len(".scene.json")]
    return os.path.splitext(base)[0]


def load_json_obj(path: str) -> dict[str, Any]:
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        die(f"invalid JSON: {path} ({e})")
    if not isinstance(data, dict):
        die(f"JSON top-level object required: {path}")
    return data


def list_scene_files(path: str) -> list[str]:
    if os.path.isfile(path):
        return [os.path.abspath(path)]
    if os.path.isdir(path):
        out: list[str] = []
        for root, _, files in os.walk(path):
            for name in files:
                if name.endswith(".scene.json"):
                    out.append(os.path.abspath(os.path.join(root, name)))
        return sorted(out)
    die(f"scene input is not a file or directory: {path}")


def as_id(value: str, prefix: str) -> str:
    if "/" in value:
        return value
    cleaned = value.strip().replace(" ", "_").replace("-", "_")
    return f"{prefix}/{cleaned}"


def normalize_graph_native(scene: dict[str, Any], _scene_rel: str) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    nodes = scene.get("nodes")
    edges = scene.get("edges")
    if not isinstance(nodes, list) or not isinstance(edges, list):
        die("graph_native scene requires nodes[] and edges[]")

    out_nodes: list[dict[str, Any]] = []
    for i, node in enumerate(nodes):
        if not isinstance(node, dict):
            die(f"graph_native node #{i} must be an object")
        node_id = node.get("id")
        if not isinstance(node_id, str) or not node_id:
            die(f"graph_native node #{i} missing string id")
        out_nodes.append(node)

    out_edges: list[dict[str, Any]] = []
    for i, edge in enumerate(edges):
        if not isinstance(edge, dict):
            die(f"graph_native edge #{i} must be an object")
        for key in ("from", "to", "type"):
            v = edge.get(key)
            if not isinstance(v, str) or not v:
                die(f"graph_native edge #{i} missing string field: {key}")
        out_edges.append(edge)

    return out_nodes, out_edges


def normalize_phase_history(scene: dict[str, Any], scene_rel: str) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    project_id = scene.get("project_id")
    phase_events = scene.get("phase_events")
    if not isinstance(project_id, str) or not project_id:
        die(f"phase_history missing project_id: {scene_rel}")
    if not isinstance(phase_events, list):
        die(f"phase_history missing phase_events[]: {scene_rel}")

    project_node_id = as_id(project_id, "project")
    project_node = {
        "id": project_node_id,
        "type": "project",
        "label": project_id,
        "source_scene": scene_rel,
    }

    nodes: list[dict[str, Any]] = [project_node]
    edges: list[dict[str, Any]] = []

    for i, ev in enumerate(phase_events):
        if not isinstance(ev, dict):
            die(f"phase_event #{i} must be object: {scene_rel}")
        phase = ev.get("phase")
        entered_on = ev.get("entered_on")
        if not isinstance(phase, str) or not phase:
            die(f"phase_event #{i} missing phase: {scene_rel}")
        if not isinstance(entered_on, str) or not entered_on:
            die(f"phase_event #{i} missing entered_on: {scene_rel}")

        event_id = f"phase_event/{project_id}/{entered_on}/{phase}"
        nodes.append(
            {
                "id": event_id,
                "type": "phase_event",
                "label": f"{project_id} {phase} {entered_on}",
                "phase": phase,
                "entered_on": entered_on,
                "trigger_artifact": ev.get("trigger_artifact"),
                "confidence_score": ev.get("confidence_score"),
                "source_scene": scene_rel,
            }
        )
        edges.append({"from": project_node_id, "to": event_id, "type": "has_phase_event"})

    return nodes, edges


def normalize_custom_object(scene: dict[str, Any], scene_rel: str) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    raw_id = scene.get("id")
    if not isinstance(raw_id, str) or not raw_id:
        raw_id = scene.get("artifact")
    raw_type = scene.get("type")
    if not isinstance(raw_id, str) or not raw_id:
        die(f"custom_object missing id/artifact: {scene_rel}")
    if not isinstance(raw_type, str) or not raw_type:
        die(f"custom_object missing type: {scene_rel}")

    source_id = as_id(raw_id, raw_type)
    node = {
        "id": source_id,
        "type": raw_type,
        "label": scene.get("title") if isinstance(scene.get("title"), str) else raw_id,
        "summary": scene.get("summary"),
        "tags": scene.get("tags") if isinstance(scene.get("tags"), list) else [],
        "source_scene": scene_rel,
    }

    edges: list[dict[str, Any]] = []
    rels = scene.get("relations")
    if isinstance(rels, list):
        for i, rel in enumerate(rels):
            if not isinstance(rel, dict):
                die(f"relation #{i} must be object: {scene_rel}")
            rel_type = rel.get("type")
            if not isinstance(rel_type, str) or not rel_type:
                die(f"relation #{i} missing type: {scene_rel}")
            target = rel.get("target")
            to_value = rel.get("to")
            if isinstance(target, str) and target:
                to_id = as_id(target, "concept")
                from_id = source_id
            elif isinstance(to_value, str) and to_value:
                from_value = rel.get("from")
                from_id = as_id(from_value, "concept") if isinstance(from_value, str) and from_value else source_id
                to_id = as_id(to_value, "concept")
            else:
                die(f"relation #{i} missing target/to: {scene_rel}")
            edges.append({"from": from_id, "to": to_id, "type": rel_type})

    return [node], edges


def normalize_document_scene(scene: dict[str, Any], scene_rel: str) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    raw_type = scene.get("type") if isinstance(scene.get("type"), str) and scene.get("type") else "scene_document"
    raw_id = scene.get("id")
    if not isinstance(raw_id, str) or not raw_id:
        raw_id = scene.get("artifact")
    if not isinstance(raw_id, str) or not raw_id:
        raw_id = scene_stem(scene_rel)

    meta = scene.get("meta") if isinstance(scene.get("meta"), dict) else {}
    title = scene.get("title")
    if not isinstance(title, str) or not title:
        title = meta.get("name") if isinstance(meta.get("name"), str) else raw_id

    summary = scene.get("summary")
    if not isinstance(summary, str) and not isinstance(summary, dict):
        summary = scene.get("purpose")
    if not isinstance(summary, str) and not isinstance(summary, dict):
        summary = meta.get("purpose")

    source_id = as_id(raw_id, raw_type)
    node = {
        "id": source_id,
        "type": raw_type,
        "label": title,
        "summary": summary,
        "tags": scene.get("tags") if isinstance(scene.get("tags"), list) else [],
        "source_scene": scene_rel,
    }

    edges: list[dict[str, Any]] = []
    rels = scene.get("relations")
    if isinstance(rels, list):
        for i, rel in enumerate(rels):
            if not isinstance(rel, dict):
                die(f"relation #{i} must be object: {scene_rel}")
            rel_type = rel.get("type")
            if not isinstance(rel_type, str) or not rel_type:
                die(f"relation #{i} missing type: {scene_rel}")
            target = rel.get("target")
            to_value = rel.get("to")
            if isinstance(target, str) and target:
                to_id = as_id(target, "concept")
                from_id = source_id
            elif isinstance(to_value, str) and to_value:
                from_value = rel.get("from")
                from_id = as_id(from_value, "concept") if isinstance(from_value, str) and from_value else source_id
                to_id = as_id(to_value, "concept")
            else:
                die(f"relation #{i} missing target/to: {scene_rel}")
            edges.append({"from": from_id, "to": to_id, "type": rel_type})

    return [node], edges


def classify(scene: dict[str, Any]) -> str:
    if isinstance(scene.get("nodes"), list) and isinstance(scene.get("edges"), list):
        return "graph_native"
    if all(k in scene for k in ("schema_version", "project_id", "phase_events")):
        return "phase_history"
    if isinstance(scene.get("type"), str) and (
        isinstance(scene.get("id"), str) or isinstance(scene.get("artifact"), str)
    ):
        return "custom_object"
    return "document_scene"


def sort_nodes(nodes: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted(nodes, key=lambda n: (str(n.get("id", "")), str(n.get("type", ""))))


def sort_edges(edges: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted(edges, key=lambda e: (str(e.get("from", "")), str(e.get("to", "")), str(e.get("type", ""))))


if os.path.exists(graph_path):
    graph = load_json_obj(graph_path)
    if not isinstance(graph.get("nodes"), list) or not isinstance(graph.get("edges"), list):
        die(f"graph file must contain nodes[] and edges[]: {graph_path}")
else:
    graph = {"nodes": [], "edges": []}

scene_files = list_scene_files(scene_input)
if not scene_files:
    die(f"no .scene.json files found: {scene_input}")

scene_files = sorted(scene_files, key=lambda p: normalize_path(p))

node_map: dict[str, dict[str, Any]] = {}
for node in graph["nodes"]:
    if isinstance(node, dict) and isinstance(node.get("id"), str) and node["id"]:
        node_map[node["id"]] = node

edge_map: dict[tuple[str, str, str], dict[str, Any]] = {}
for edge in graph["edges"]:
    if not isinstance(edge, dict):
        continue
    a, b, c = edge.get("from"), edge.get("to"), edge.get("type")
    if all(isinstance(v, str) and v for v in (a, b, c)):
        edge_map[(a, b, c)] = edge

nodes_added = 0
nodes_updated = 0
edges_added = 0
edges_deduped = 0

for scene_path in scene_files:
    scene_rel = normalize_path(scene_path)
    scene = load_json_obj(scene_path)
    scene_type = classify(scene)

    if scene_type == "graph_native":
        nodes, edges = normalize_graph_native(scene, scene_rel)
    elif scene_type == "phase_history":
        nodes, edges = normalize_phase_history(scene, scene_rel)
    elif scene_type == "custom_object":
        nodes, edges = normalize_custom_object(scene, scene_rel)
    elif scene_type == "document_scene":
        nodes, edges = normalize_document_scene(scene, scene_rel)
    else:
        die(f"unsupported scene shape: {scene_rel}")

    for node in sort_nodes(nodes):
        node_id = node["id"]
        if node_id not in node_map:
            nodes_added += 1
        elif node_map[node_id] != node:
            nodes_updated += 1
        node_map[node_id] = node

    for edge in sort_edges(edges):
        key = (edge["from"], edge["to"], edge["type"])
        if key in edge_map:
            edges_deduped += 1
        else:
            edges_added += 1
        edge_map[key] = edge

final_graph = {
    "nodes": sort_nodes(list(node_map.values())),
    "edges": sort_edges(list(edge_map.values())),
}

summary = {
    "mode": mode,
    "graph_path": normalize_path(graph_path),
    "scenes_processed": len(scene_files),
    "nodes_added": nodes_added,
    "nodes_updated": nodes_updated,
    "edges_added": edges_added,
    "edges_deduped": edges_deduped,
}

if mode == "apply":
    with open(graph_path, "w", encoding="utf-8") as f:
        json.dump(final_graph, f, indent=2)
        f.write("\n")

print(json.dumps(summary, indent=2))
PY
