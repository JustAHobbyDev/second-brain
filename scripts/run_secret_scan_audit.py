#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import subprocess
from datetime import date
from pathlib import Path
from typing import Any


TARGET_NAMESPACE = "mixed"
ALLOWED_PATH_PREFIXES = ["reports/"]
BOUNDARY_JUSTIFICATION = (
    "Reads tracked files repository-wide and writes a track-only audit report under reports/."
)

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = REPO_ROOT / "reports" / "secret_scan_audit_v0.json"

PATTERNS: list[tuple[str, re.Pattern[str], str]] = [
    (
        "openai_project_key",
        re.compile(r"\bsk-proj-[A-Za-z0-9_-]{20,}\b"),
        "high",
    ),
    (
        "openai_legacy_key",
        re.compile(r"\bsk-[A-Za-z0-9]{32,}\b"),
        "high",
    ),
    (
        "openai_env_assignment",
        re.compile(r"\bOPENAI_API_KEY\s*[:=]\s*['\"]?[^'\"\s]{20,}"),
        "high",
    ),
    (
        "github_token",
        re.compile(r"\bgh[pousr]_[A-Za-z0-9]{20,}\b"),
        "high",
    ),
]

REDACTION_PATTERNS: list[re.Pattern[str]] = [
    re.compile(r"\bsk-proj-[A-Za-z0-9_-]{20,}\b"),
    re.compile(r"\bsk-[A-Za-z0-9]{32,}\b"),
    re.compile(r"\bgh[pousr]_[A-Za-z0-9]{20,}\b"),
    re.compile(r"(\bOPENAI_API_KEY\s*[:=]\s*['\"]?)[^'\"\s]+"),
]

EXAMPLE_HINTS = (
    "example",
    "placeholder",
    "redacted",
    "sample",
    "your_key",
    "<key>",
    "<token>",
)


def list_tracked_files(repo_root: Path) -> list[Path]:
    try:
        out = subprocess.check_output(
            ["git", "ls-files", "-z"],
            cwd=repo_root,
        )
    except subprocess.CalledProcessError:
        return []
    except FileNotFoundError:
        return []

    rel_paths = [p for p in out.decode("utf-8", errors="ignore").split("\0") if p]
    paths: list[Path] = []
    for rel in rel_paths:
        path = (repo_root / rel).resolve()
        if path.is_file():
            paths.append(path)
    return paths


def looks_binary(path: Path) -> bool:
    try:
        sample = path.read_bytes()[:4096]
    except OSError:
        return True
    return b"\0" in sample


def is_example_line(line: str) -> bool:
    lower = line.lower()
    return any(hint in lower for hint in EXAMPLE_HINTS)


def redact_line(line: str) -> str:
    redacted = line
    for pattern in REDACTION_PATTERNS:
        if pattern.pattern.startswith("(\\bOPENAI_API_KEY"):
            redacted = pattern.sub(r"\1<redacted_secret>", redacted)
        else:
            redacted = pattern.sub("<redacted_secret>", redacted)
    return redacted


def collect_report(repo_root: Path, max_matches: int) -> dict[str, Any]:
    tracked = list_tracked_files(repo_root)
    tracked_count = len(tracked)

    text_scanned = 0
    binary_skipped = 0
    read_errors = 0
    example_hits_ignored = 0
    matches: list[dict[str, Any]] = []

    for path in tracked:
        rel = str(path.relative_to(repo_root))
        if looks_binary(path):
            binary_skipped += 1
            continue

        try:
            lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
        except OSError:
            read_errors += 1
            continue

        text_scanned += 1
        for idx, line in enumerate(lines, start=1):
            if is_example_line(line):
                # Keep false-positive pressure low in docs and templates.
                if any(regex.search(line) for _, regex, _ in PATTERNS):
                    example_hits_ignored += 1
                continue

            line_match = False
            for pattern_id, regex, severity in PATTERNS:
                if not regex.search(line):
                    continue
                line_match = True
                if len(matches) < max_matches:
                    matches.append(
                        {
                            "path": rel,
                            "line": idx,
                            "pattern_id": pattern_id,
                            "severity": severity,
                            "snippet": redact_line(line).strip()[:220],
                        }
                    )
            if line_match and len(matches) >= max_matches:
                break

    high_confidence = sum(1 for m in matches if m.get("severity") == "high")
    status = "ok" if not matches else "warning"

    next_actions = [
        "If any match is real, rotate affected credential and remove it from tracked files immediately.",
        "Rewrite history only when a real secret was committed to tracked history.",
        "Keep secrets in untracked local env files and validate with recurring audits.",
    ]

    return {
        "artifact_id": f"artifact/secret_scan_audit_{date.today().strftime('%Y_%m_%d')}_v0",
        "audit_date": date.today().isoformat(),
        "scope": "project/dan_personal_cognitive_infrastructure",
        "status": status,
        "summary": {
            "tracked_files": tracked_count,
            "text_files_scanned": text_scanned,
            "binary_files_skipped": binary_skipped,
            "read_errors": read_errors,
            "matches_found": len(matches),
            "high_confidence_matches": high_confidence,
            "example_hits_ignored": example_hits_ignored,
            "max_matches": max_matches,
        },
        "thresholds": {
            "secret_matches_warn_gt": 0,
        },
        "matches": matches,
        "next_actions": next_actions,
        "policy_note": "Track-only audit. No automatic mutation.",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Scan tracked files for likely committed secrets.")
    parser.add_argument("--repo-root", default=str(REPO_ROOT), help="Repository root path")
    parser.add_argument("--out-file", default=str(DEFAULT_OUT), help="Output report JSON path")
    parser.add_argument("--max-matches", type=int, default=200, help="Maximum matches to include in report")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    out_file = Path(args.out_file).resolve()
    report = collect_report(repo_root=repo_root, max_matches=max(1, args.max_matches))
    out_file.parent.mkdir(parents=True, exist_ok=True)
    out_file.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
