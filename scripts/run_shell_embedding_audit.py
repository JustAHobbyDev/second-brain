#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from datetime import date
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = REPO_ROOT / "reports" / "shell_embedding_audit_v0.json"


def is_bash_script(path: Path) -> bool:
    if path.suffix == ".sh":
        return True
    try:
        first = path.read_text(encoding="utf-8", errors="ignore").splitlines()[:1]
    except Exception:
        return False
    if not first:
        return False
    return first[0].startswith("#!/usr/bin/env bash") or first[0].startswith("#!/bin/bash")


def find_python_heredocs(text: str) -> list[dict[str, Any]]:
    lines = text.splitlines()
    blocks: list[dict[str, Any]] = []
    i = 0
    cmd_re = re.compile(r"\bpython(?:3)?\b[^\n]*<<-?\s*['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?")
    while i < len(lines):
        line = lines[i]
        m = cmd_re.search(line)
        if not m:
            i += 1
            continue
        tag = m.group(1)
        start_line = i + 1
        j = i + 1
        while j < len(lines):
            if lines[j].strip() == tag:
                break
            j += 1
        if j >= len(lines):
            block_lines = len(lines) - (i + 1)
            end_line = len(lines)
            closed = False
            i = len(lines)
        else:
            block_lines = j - (i + 1)
            end_line = j + 1
            closed = True
            i = j + 1
        blocks.append(
            {
                "tag": tag,
                "start_line": start_line,
                "end_line": end_line,
                "python_lines": block_lines,
                "closed": closed,
            }
        )
    return blocks


def collect_report(repo_root: Path) -> dict[str, Any]:
    scripts = []
    for p in sorted(repo_root.rglob("*")):
        if not p.is_file():
            continue
        if ".git" in p.parts:
            continue
        if not is_bash_script(p):
            continue
        scripts.append(p)

    entries = []
    total_blocks = 0
    total_python_lines = 0
    max_block_lines = 0
    unclosed_blocks = 0

    for path in scripts:
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        blocks = find_python_heredocs(text)
        if not blocks:
            continue
        block_lines = [int(b["python_lines"]) for b in blocks]
        total_blocks += len(blocks)
        total_python_lines += sum(block_lines)
        max_block_lines = max(max_block_lines, max(block_lines))
        unclosed_blocks += sum(1 for b in blocks if not b["closed"])
        entries.append(
            {
                "path": str(path.relative_to(repo_root)),
                "embedded_python_blocks": len(blocks),
                "embedded_python_lines_total": sum(block_lines),
                "max_block_lines": max(block_lines),
                "blocks": blocks,
            }
        )

    total_bash = len(scripts)
    with_embedded = len(entries)
    pct_embedded = round((100.0 * with_embedded / total_bash), 2) if total_bash else 0.0

    status = "ok"
    alerts = []
    if unclosed_blocks > 0:
        status = "warning"
        alerts.append("Found unclosed python heredoc block(s) in bash scripts.")
    if max_block_lines > 140:
        status = "warning"
        alerts.append("At least one embedded python block exceeds 140 lines.")
    if pct_embedded > 70.0:
        status = "warning"
        alerts.append("More than 70% of bash scripts embed python blocks.")

    top_offenders = sorted(
        entries,
        key=lambda e: (int(e["max_block_lines"]), int(e["embedded_python_lines_total"])),
        reverse=True,
    )[:5]

    next_actions = [
        "Extract largest embedded python blocks (>140 lines) into scripts/*.py modules.",
        "Prefer shared python modules for repeated JSON mutation logic across bash wrappers.",
        "Keep inline python for short, single-purpose glue code only.",
    ]

    return {
        "artifact_id": f"artifact/shell_embedding_audit_{date.today().strftime('%Y_%m_%d')}_v0",
        "audit_date": date.today().isoformat(),
        "scope": "project/dan_personal_cognitive_infrastructure",
        "status": status,
        "summary": {
            "total_bash_scripts": total_bash,
            "bash_with_embedded_python": with_embedded,
            "embedded_python_pct": pct_embedded,
            "embedded_python_blocks": total_blocks,
            "embedded_python_lines_total": total_python_lines,
            "max_block_lines": max_block_lines,
            "unclosed_blocks": unclosed_blocks,
        },
        "alerts": alerts,
        "thresholds": {
            "embedded_python_pct_warn_gt": 70.0,
            "max_block_lines_warn_gt": 140,
            "unclosed_blocks_warn_gt": 0,
        },
        "top_offenders": top_offenders,
        "offenders": entries,
        "next_actions": next_actions,
        "policy_note": "Track-only audit. No automatic mutation.",
    }


def main() -> None:
    ap = argparse.ArgumentParser(description="Audit bash scripts for embedded python heredoc usage")
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

