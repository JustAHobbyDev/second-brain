#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from datetime import date
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = REPO_ROOT / "reports" / "namespace_boundary_audit_v0.json"

SH_MUTATION_PATTERNS = [
    r">>",
    r"\btee\b",
    r"\btouch\b",
    r"\bmkdir\b",
    r"\bcp\b",
    r"\bmv\b",
    r"\brm\b",
    r"\bgit\s+add\b",
    r"\bcat\b[^\n]*>\s*",
    r"\becho\b[^\n]*>\s*",
    r"\bprintf\b[^\n]*>\s*",
]

PY_MUTATION_PATTERNS = [
    r"\.write_text\(",
    r"\.write_bytes\(",
    r"open\([^)]*,\s*['\"](?:w|a|x|wb|ab|xb)['\"]",
    r"json\.dump\(",
    r"\bshutil\.(?:copy|copy2|copytree|move|rmtree)\(",
    r"\.mkdir\(",
]


def load_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def find_scripts(repo_root: Path) -> list[Path]:
    candidates: list[Path] = []
    for base in (repo_root / "tools", repo_root / "scripts"):
        if not base.exists():
            continue
        for p in sorted(base.rglob("*")):
            if not p.is_file():
                continue
            if p.suffix in {".sh", ".py"}:
                candidates.append(p)
    return candidates


def detect_script_type(path: Path, text: str) -> str:
    if path.suffix == ".sh" or text.startswith("#!/usr/bin/env bash") or text.startswith("#!/bin/bash"):
        return "bash"
    if path.suffix == ".py" or text.startswith("#!/usr/bin/env python3") or text.startswith("#!/usr/bin/python3"):
        return "python"
    return "unknown"


def is_mutating(script_type: str, text: str) -> bool:
    patterns = SH_MUTATION_PATTERNS if script_type == "bash" else PY_MUTATION_PATTERNS
    return any(re.search(p, text) for p in patterns)


def parse_declared_namespace(script_type: str, text: str) -> str | None:
    if script_type == "bash":
        m = re.search(r"^\s*TARGET_NAMESPACE\s*=\s*[\"']?([A-Za-z_]+)[\"']?\s*$", text, flags=re.M)
        return m.group(1) if m else None
    m = re.search(r"^\s*TARGET_NAMESPACE\s*=\s*[\"']([A-Za-z_]+)[\"']\s*$", text, flags=re.M)
    return m.group(1) if m else None


def has_decl(field: str, script_type: str, text: str) -> bool:
    if script_type == "bash":
        return re.search(rf"^\s*{re.escape(field)}\s*=", text, flags=re.M) is not None
    return re.search(rf"^\s*{re.escape(field)}\s*=", text, flags=re.M) is not None


def collect_report(repo_root: Path) -> dict[str, Any]:
    scanned = 0
    mutating = 0
    declared = 0
    missing = []

    for path in find_scripts(repo_root):
        text = load_text(path)
        script_type = detect_script_type(path, text)
        if script_type not in {"bash", "python"}:
            continue
        scanned += 1
        if not is_mutating(script_type, text):
            continue
        mutating += 1

        target_ns = parse_declared_namespace(script_type, text)
        missing_fields = []

        if not has_decl("TARGET_NAMESPACE", script_type, text):
            missing_fields.append("TARGET_NAMESPACE")
        if not has_decl("ALLOWED_PATH_PREFIXES", script_type, text):
            missing_fields.append("ALLOWED_PATH_PREFIXES")
        if target_ns == "mixed" and not has_decl("BOUNDARY_JUSTIFICATION", script_type, text):
            missing_fields.append("BOUNDARY_JUSTIFICATION")

        if missing_fields:
            missing.append(
                {
                    "path": str(path.relative_to(repo_root)),
                    "script_type": script_type,
                    "target_namespace_detected": target_ns,
                    "missing_fields": missing_fields,
                }
            )
        else:
            declared += 1

    status = "ok" if not missing else "warning"
    next_actions = [
        "Add TARGET_NAMESPACE and ALLOWED_PATH_PREFIXES to all mutating tools.",
        "Use TARGET_NAMESPACE=mixed only with explicit BOUNDARY_JUSTIFICATION.",
        "Re-run namespace audit each recurring audit loop and reduce missing declarations over time.",
    ]

    return {
        "artifact_id": f"artifact/namespace_boundary_audit_{date.today().strftime('%Y_%m_%d')}_v0",
        "audit_date": date.today().isoformat(),
        "scope": "project/dan_personal_cognitive_infrastructure",
        "status": status,
        "summary": {
            "scripts_scanned": scanned,
            "mutating_tool_candidates": mutating,
            "declarations_complete": declared,
            "missing_declaration_count": len(missing),
        },
        "thresholds": {
            "missing_declaration_warn_gt": 0,
        },
        "missing_declarations": missing,
        "next_actions": next_actions,
        "policy_note": "Track-only audit. No automatic mutation.",
    }


def main() -> None:
    ap = argparse.ArgumentParser(description="Audit namespace-boundary declarations in mutating tools")
    ap.add_argument("--repo-root", default=str(REPO_ROOT), help="Repository root path")
    ap.add_argument("--out-file", default=str(DEFAULT_OUT), help="Output report JSON path")
    args = ap.parse_args()

    repo_root = Path(args.repo_root).resolve()
    out_file = Path(args.out_file)
    report = collect_report(repo_root)
    out_file.parent.mkdir(parents=True, exist_ok=True)
    out_file.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()

