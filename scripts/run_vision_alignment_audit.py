#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
SESSIONS_DIR = REPO_ROOT / "sessions"
SCENES_DIR = REPO_ROOT / "scenes"
DEFAULT_OUT = REPO_ROOT / "reports" / "vision_alignment_audit_v0.json"


@dataclass
class ArtifactEval:
    artifact_id: str
    has_principle_link: bool
    principles_total: int
    principles_canonical: int
    patterns_total: int
    is_non_trivial: bool


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def canonical_principle_ids() -> set[str]:
    out: set[str] = set()
    for p in sorted(SCENES_DIR.glob("*.scene.json")):
        try:
            data = load_json(p)
        except Exception:
            continue
        nodes = data.get("nodes") if isinstance(data, dict) else None
        if not isinstance(nodes, list):
            continue
        for node in nodes:
            if isinstance(node, dict):
                nid = node.get("id")
                if isinstance(nid, str) and nid.startswith("principle/"):
                    out.add(nid)
    return out


def extract_eval(obj: dict[str, Any], canonical: set[str]) -> ArtifactEval | None:
    artifact_id = obj.get("artifact_id") or obj.get("id")
    if not isinstance(artifact_id, str):
        return None

    principles: list[str] = []
    patterns: list[str] = []

    p_links = obj.get("principle_links")
    if isinstance(p_links, list):
        principles.extend(x for x in p_links if isinstance(x, str))
    links = obj.get("links")
    if isinstance(links, dict):
        p2 = links.get("principles")
        if isinstance(p2, list):
            principles.extend(x for x in p2 if isinstance(x, str))

    pat_links = obj.get("pattern_links")
    if isinstance(pat_links, list):
        patterns.extend(x for x in pat_links if isinstance(x, str))
    if isinstance(links, dict):
        pat2 = links.get("patterns_used")
        if isinstance(pat2, list):
            patterns.extend(x for x in pat2 if isinstance(x, str))

    summary = obj.get("summary")
    has_summary = False
    has_decision_or_step = False

    if isinstance(summary, str):
        has_summary = bool(summary.strip())
    elif isinstance(summary, dict):
        hl = summary.get("high_level")
        has_summary = isinstance(hl, str) and bool(hl.strip())
        kd = summary.get("key_decisions")
        has_decision_or_step = isinstance(kd, list) and any(isinstance(x, str) and x.strip() for x in kd)

    kd2 = obj.get("key_decisions")
    ns2 = obj.get("next_steps")
    if isinstance(kd2, list) and any(isinstance(x, str) and x.strip() for x in kd2):
        has_decision_or_step = True
    if isinstance(ns2, list) and any(isinstance(x, str) and x.strip() for x in ns2):
        has_decision_or_step = True

    non_trivial = has_summary and has_decision_or_step

    canon_count = sum(1 for p in principles if p in canonical)
    return ArtifactEval(
        artifact_id=artifact_id,
        has_principle_link=canon_count > 0,
        principles_total=len(principles),
        principles_canonical=canon_count,
        patterns_total=len(patterns),
        is_non_trivial=non_trivial,
    )


def run_audit(sessions_dir: Path, out_file: Path) -> dict[str, Any]:
    canonical = canonical_principle_ids()
    evals: list[ArtifactEval] = []

    for tool_dir in sorted([p for p in sessions_dir.iterdir() if p.is_dir()]):
        for jf in sorted(tool_dir.glob("*.json")):
            if jf.name == "index.json":
                continue
            try:
                obj = load_json(jf)
            except Exception:
                continue
            if not isinstance(obj, dict):
                continue
            ev = extract_eval(obj, canonical)
            if ev is not None:
                evals.append(ev)

    eligible = [e for e in evals if e.is_non_trivial]
    with_principle = [e for e in eligible if e.has_principle_link]

    pct = 0.0
    if eligible:
        pct = round(100.0 * len(with_principle) / len(eligible), 2)

    bucket = {
        "pass": ">=75%",
        "stretch": ">=85%",
    }

    status = "fail"
    if pct >= 85.0:
        status = "stretch"
    elif pct >= 75.0:
        status = "pass"

    weak_ids = [e.artifact_id for e in eligible if not e.has_principle_link]

    report = {
        "artifact_id": f"artifact/vision_alignment_audit_{date.today().strftime('%Y_%m_%d')}_v0",
        "audit_date": date.today().isoformat(),
        "kpi": {
            "name": "principle_linked_artifact_pct",
            "definition": "Percent of non-trivial session artifacts with >=1 canonical principle link",
            "eligible_artifacts": len(eligible),
            "artifacts_with_principle_link": len(with_principle),
            "value_pct": pct,
            "targets": bucket,
            "status": status,
        },
        "coverage": {
            "total_artifacts_scanned": len(evals),
            "canonical_principle_ids_detected": len(canonical),
            "artifacts_missing_principle_link": weak_ids,
        },
        "next_actions": [
            "Require >=2 principle links in closeout unless explicitly justified",
            "Add canonical principle IDs to artifacts currently missing principle links",
            "Track week-over-week trend for principle_linked_artifact_pct",
        ],
    }

    out_file.parent.mkdir(parents=True, exist_ok=True)
    out_file.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


def main() -> None:
    ap = argparse.ArgumentParser(description="Run second-brain vision-alignment KPI audit")
    ap.add_argument("--sessions-dir", default=str(SESSIONS_DIR), help="Path to sessions dir")
    ap.add_argument("--out-file", default=str(DEFAULT_OUT), help="Output JSON report path")
    args = ap.parse_args()

    report = run_audit(Path(args.sessions_dir), Path(args.out_file))
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
