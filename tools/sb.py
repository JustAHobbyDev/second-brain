#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, cast

JsonObj = dict[str, Any]

REPO_ROOT = Path(__file__).resolve().parents[1]
SESSIONS_DIR = REPO_ROOT / "sessions"
SCENES_DIR = REPO_ROOT / "scenes"


def die(msg: str, code: int = 1) -> None:
    print(f"error: {msg}", file=sys.stderr)
    raise SystemExit(code)


def read_json_from_stdin() -> JsonObj:
    raw = sys.stdin.read()
    if not raw.strip():
        die("no input on stdin. Pipe JSON into this command.")
    try:
        value = json.loads(raw)
    except Exception as e:
        die(f"stdin is not valid JSON: {e}")
    if not isinstance(value, dict):
        die("stdin JSON must be an object at the top level.")
    return cast(JsonObj, value)


def read_json_input(json_file: str | None) -> JsonObj:
    if json_file:
        return read_json_file(Path(json_file))
    return read_json_from_stdin()


def read_index_file(path: Path) -> list[str]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except Exception as e:
        die(f"invalid JSON file: {path} ({e})")
    if not isinstance(value, list):
        die(f"index.json must be a JSON array: {path}")
    out: list[str] = []
    for i, item in enumerate(value):
        if not isinstance(item, str):
            die(f"index.json item #{i} must be a string: {path}")
        out.append(item)
    return out


def read_json_file(path: Path) -> JsonObj:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except Exception as e:
        die(f"invalid JSON file: {path} ({e})")
    if not isinstance(value, dict):
        die(f"JSON file must be an object at top level: {path}")
    return cast(JsonObj, value)


def write_json_file(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=False) + "\n", encoding="utf-8")


def slugify(s: str) -> str:
    keep: list[str] = []
    for ch in s.lower():
        if ch.isalnum():
            keep.append(ch)
        elif ch in ["-", "_", " "]:
            keep.append("-")
    out = "".join(keep)
    while "--" in out:
        out = out.replace("--", "-")
    return out.strip("-")


def infer_filename_from_artifact_id(artifact_id: str) -> str:
    # artifact/chatgpt_session_2026_02_11_second_brain_architecture -> 2026-02-11-second-brain-architecture.json
    if not artifact_id.startswith("artifact/"):
        die(f"artifact id must start with 'artifact/': {artifact_id}")

    tail = artifact_id.split("/", 1)[1]
    parts = tail.split("_")

    date_idx: int | None = None
    for i in range(len(parts) - 2):
        a, b, c = parts[i], parts[i + 1], parts[i + 2]
        if len(a) == 4 and len(b) == 2 and len(c) == 2 and a.isdigit() and b.isdigit() and c.isdigit():
            date_idx = i
            break

    if date_idx is None:
        date_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        slug = slugify(tail)
        return f"{date_str}-{slug}.json"

    yyyy, mm, dd = parts[date_idx], parts[date_idx + 1], parts[date_idx + 2]
    date_str = f"{yyyy}-{mm}-{dd}"
    slug_parts = parts[date_idx + 3 :]
    slug = slugify("-".join(slug_parts)) if slug_parts else slugify(tail)
    return f"{date_str}-{slug}.json"


def rebuild_indexes() -> None:
    if not SESSIONS_DIR.exists():
        return

    for tool_dir in sorted([p for p in SESSIONS_DIR.iterdir() if p.is_dir()]):
        idx_path = tool_dir / "index.json"
        ids: set[str] = set()

        for f in sorted(tool_dir.glob("*.json")):
            if f.name == "index.json":
                continue
            try:
                data = read_json_file(f)
                artifact_id = data.get("id")
                if isinstance(artifact_id, str) and artifact_id.startswith("artifact/"):
                    ids.add(artifact_id)
            except SystemExit:
                # skip invalid JSON; validate will catch
                continue

        write_json_file(idx_path, sorted(ids))


def cmd_commit_session(args: argparse.Namespace) -> None:
    data = read_json_input(cast(str | None, args.json_file))
    artifact_id = data.get("id")
    if not isinstance(artifact_id, str):
        die("session JSON must contain a string field 'id' (artifact/...)")

    tool = cast(str, args.tool)
    if tool not in ("codex", "chatgpt"):
        die("tool must be one of: codex, chatgpt")

    out_dir = SESSIONS_DIR / tool
    filename_arg = cast(str | None, args.filename)
    out_name = filename_arg or infer_filename_from_artifact_id(artifact_id)
    out_path = out_dir / out_name

    write_json_file(out_path, data)
    rebuild_indexes()
    print(str(out_path))


def cmd_commit_scene(args: argparse.Namespace) -> None:
    data = read_json_input(cast(str | None, args.json_file))
    name = cast(str, args.name)
    if not name:
        die("scene name required (example: workflow_operational_model)")

    out_path = SCENES_DIR / f"{slugify(name)}.scene.json"
    write_json_file(out_path, data)
    print(str(out_path))


def cmd_validate(_args: argparse.Namespace) -> None:
    errors = 0

    if SCENES_DIR.exists():
        for f in sorted(SCENES_DIR.glob("*.json")):
            try:
                _ = read_json_file(f)
            except SystemExit:
                errors += 1

    if SESSIONS_DIR.exists():
        for tool_dir in sorted([p for p in SESSIONS_DIR.iterdir() if p.is_dir()]):
            for f in sorted(tool_dir.glob("*.json")):
                try:
                    if f.name == "index.json":
                        _ = read_index_file(f)
                    else:
                        _ = read_json_file(f)
                except SystemExit:
                    errors += 1

    if errors:
        die(f"validation failed with {errors} error(s)")
    print("ok")


def cmd_reindex(_args: argparse.Namespace) -> None:
    rebuild_indexes()
    print("reindexed")


def main() -> None:
    p = argparse.ArgumentParser(prog="sb", description="Second-brain CLI")
    sub = p.add_subparsers(dest="cmd", required=True)

    s1 = sub.add_parser(
        "commit-session",
        help="Commit a session artifact from stdin JSON (or --json-file) and rebuild indexes",
    )
    _ = s1.add_argument("--tool", required=True, choices=["codex", "chatgpt"])
    _ = s1.add_argument("--filename", help="Override output filename")
    _ = s1.add_argument("--json-file", help="Read input JSON from a file instead of stdin")
    s1.set_defaults(func=cmd_commit_session)

    s2 = sub.add_parser("commit-scene", help="Commit a scene JSON from stdin (or --json-file)")
    _ = s2.add_argument("--name", required=True, help="Scene name (used for filename)")
    _ = s2.add_argument("--json-file", help="Read input JSON from a file instead of stdin")
    s2.set_defaults(func=cmd_commit_scene)

    s3 = sub.add_parser("validate", help="Validate JSON in scenes/ and sessions/")
    s3.set_defaults(func=cmd_validate)

    s4 = sub.add_parser("reindex", help="Rebuild sessions/*/index.json from session artifacts")
    s4.set_defaults(func=cmd_reindex)

    args = p.parse_args()
    func = cast(Callable[[argparse.Namespace], None], getattr(args, "func", None))
    if func is None:
        die("no command provided")
    func(args)


if __name__ == "__main__":
    main()
