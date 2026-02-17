#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any


TARGET_NAMESPACE = "scene"
ALLOWED_PATH_PREFIXES = ["scene/audit_reports/v0/"]

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REGISTRY = REPO_ROOT / "scene" / "authority" / "registry_v0.json"
DEFAULT_MERGE_QUEUE = REPO_ROOT / "scene" / "merge_queue" / "queue_v0.json"
DEFAULT_OUT = REPO_ROOT / "scene" / "audit_reports" / "v0" / f"beads_boundary_audit_{date.today().strftime('%Y_%m_%d')}_v0.json"

DISALLOWED_BROAD_SCOPES = {"scene/", "state/", "scenes/", "project/"}
BEADS_SCOPE_PREFIXES = ("scene/beads/", "state/beads/")
SURFACE_PREFIXES = (
    "scene/beads/",
    "state/beads/",
    "scene/mailbox/",
    "scene/merge_queue/",
    "scene/sandbox/",
)


def _load_json(path: Path) -> tuple[Any | None, str | None]:
    if not path.exists():
        return None, f"missing: {path}"
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle), None
    except json.JSONDecodeError as exc:
        return None, f"invalid_json: {path} ({exc})"
    except OSError as exc:
        return None, f"read_error: {path} ({exc})"


def _is_beads_tuple(entry: dict[str, Any]) -> bool:
    authority_id = str(entry.get("authority_id", ""))
    if authority_id.startswith("auth/beads_"):
        return True
    scopes = entry.get("scope", [])
    if not isinstance(scopes, list):
        return False
    return any(isinstance(scope, str) and scope.startswith(BEADS_SCOPE_PREFIXES) for scope in scopes)


def _surface_for_scope(scope: str) -> str | None:
    for prefix in SURFACE_PREFIXES:
        if scope.startswith(prefix):
            return prefix
    return None


def _audit_registry(registry: Any) -> dict[str, Any]:
    findings: list[dict[str, Any]] = []
    scanned = 0
    wildcard_violations = 0
    broad_scope_violations = 0
    multi_surface_violations = 0
    invalid_scope_format = 0

    tuples = registry.get("authority_tuples", []) if isinstance(registry, dict) else []
    if not isinstance(tuples, list):
        tuples = []

    for entry in tuples:
        if not isinstance(entry, dict) or not _is_beads_tuple(entry):
            continue

        scanned += 1
        authority_id = str(entry.get("authority_id", f"unknown_{scanned}"))
        scopes = entry.get("scope", [])
        if not isinstance(scopes, list):
            invalid_scope_format += 1
            findings.append(
                {
                    "authority_id": authority_id,
                    "issue": "invalid_scope_format",
                    "detail": "scope must be a list of repo-root-relative prefixes",
                }
            )
            continue

        surfaces: set[str] = set()
        for scope_value in scopes:
            if not isinstance(scope_value, str):
                invalid_scope_format += 1
                findings.append(
                    {
                        "authority_id": authority_id,
                        "issue": "invalid_scope_entry",
                        "detail": "scope entries must be strings",
                    }
                )
                continue

            scope = scope_value.strip()
            if "*" in scope:
                wildcard_violations += 1
                findings.append(
                    {
                        "authority_id": authority_id,
                        "issue": "wildcard_scope_disallowed",
                        "scope": scope,
                    }
                )

            normalized = scope if scope.endswith("/") else f"{scope}/"
            if normalized in DISALLOWED_BROAD_SCOPES:
                broad_scope_violations += 1
                findings.append(
                    {
                        "authority_id": authority_id,
                        "issue": "broad_scope_disallowed",
                        "scope": scope,
                    }
                )

            surface = _surface_for_scope(scope)
            if surface is not None:
                surfaces.add(surface)

        if len(surfaces) > 1:
            multi_surface_violations += 1
            findings.append(
                {
                    "authority_id": authority_id,
                    "issue": "multi_surface_tuple_disallowed",
                    "surfaces": sorted(surfaces),
                }
            )

    status = "ok"
    if wildcard_violations or broad_scope_violations or multi_surface_violations or invalid_scope_format:
        status = "warning"

    return {
        "status": status,
        "summary": {
            "beads_tuples_scanned": scanned,
            "wildcard_scope_violations": wildcard_violations,
            "broad_scope_violations": broad_scope_violations,
            "multi_surface_tuple_violations": multi_surface_violations,
            "invalid_scope_format": invalid_scope_format,
        },
        "findings": findings,
    }


def _audit_materialization(merge_queue: Any, repo_root: Path) -> dict[str, Any]:
    findings: list[dict[str, Any]] = []
    items_scanned = 0
    merged_items_scanned = 0
    materialization_violations = 0

    items = merge_queue.get("items", []) if isinstance(merge_queue, dict) else []
    if not isinstance(items, list):
        items = []

    for idx, item in enumerate(items):
        if not isinstance(item, dict):
            continue

        items_scanned += 1
        status = str(item.get("status", "")).strip().lower()
        if status != "merged":
            continue

        merged_items_scanned += 1
        merge_id = str(item.get("merge_id", f"item_{idx + 1:03d}"))
        resolution_ref = item.get("resolution_note_ref")
        if not isinstance(resolution_ref, str) or not resolution_ref.strip():
            materialization_violations += 1
            findings.append(
                {
                    "merge_id": merge_id,
                    "issue": "missing_resolution_note_ref",
                }
            )
            continue

        ref = resolution_ref.strip()
        if ref.startswith("./"):
            materialization_violations += 1
            findings.append(
                {
                    "merge_id": merge_id,
                    "issue": "non_canonical_reference_format",
                    "resolution_note_ref": ref,
                }
            )
            continue

        if not ref.startswith("scenes/"):
            materialization_violations += 1
            findings.append(
                {
                    "merge_id": merge_id,
                    "issue": "resolution_note_not_in_scenes",
                    "resolution_note_ref": ref,
                }
            )
            continue

        ref_path = repo_root / ref
        if not ref_path.exists():
            materialization_violations += 1
            findings.append(
                {
                    "merge_id": merge_id,
                    "issue": "resolution_note_missing_file",
                    "resolution_note_ref": ref,
                }
            )

    status = "ok" if materialization_violations == 0 else "warning"
    return {
        "status": status,
        "summary": {
            "merge_items_scanned": items_scanned,
            "merged_items_scanned": merged_items_scanned,
            "materialization_violations": materialization_violations,
        },
        "findings": findings,
    }


def _build_report(repo_root: Path, registry_file: Path, merge_queue_file: Path) -> dict[str, Any]:
    registry, registry_error = _load_json(registry_file)
    merge_queue, merge_error = _load_json(merge_queue_file)

    missing_inputs = [msg for msg in (registry_error, merge_error) if msg is not None]

    if registry is None:
        registry_result = {
            "status": "insufficient_input",
            "summary": {
                "beads_tuples_scanned": 0,
                "wildcard_scope_violations": 0,
                "broad_scope_violations": 0,
                "multi_surface_tuple_violations": 0,
                "invalid_scope_format": 0,
            },
            "findings": [],
        }
    else:
        registry_result = _audit_registry(registry)

    if merge_queue is None:
        materialization_result = {
            "status": "insufficient_input",
            "summary": {
                "merge_items_scanned": 0,
                "merged_items_scanned": 0,
                "materialization_violations": 0,
            },
            "findings": [],
        }
    else:
        materialization_result = _audit_materialization(merge_queue, repo_root)

    overall_status = "ok"
    if missing_inputs:
        overall_status = "insufficient_input"
    if registry_result["status"] == "warning" or materialization_result["status"] == "warning":
        overall_status = "warning"

    summary = {
        "missing_required_inputs": len(missing_inputs),
        "beads_tuples_scanned": int(registry_result["summary"]["beads_tuples_scanned"]),
        "wildcard_scope_violations": int(registry_result["summary"]["wildcard_scope_violations"]),
        "broad_scope_violations": int(registry_result["summary"]["broad_scope_violations"]),
        "multi_surface_tuple_violations": int(registry_result["summary"]["multi_surface_tuple_violations"]),
        "merge_items_scanned": int(materialization_result["summary"]["merge_items_scanned"]),
        "merged_items_scanned": int(materialization_result["summary"]["merged_items_scanned"]),
        "materialization_violations": int(materialization_result["summary"]["materialization_violations"]),
    }

    next_actions = [
        "Split Beads-scoped authority tuples to one runtime surface per tuple if violations are present.",
        "Use repo-root-relative path prefixes only; do not use wildcards in Beads-scoped tuple scope.",
        "For merged runtime proposals, write a canonical resolution note in scenes/ and keep resolution_note_ref current.",
    ]

    return {
        "artifact_id": f"artifact/beads_boundary_audit_{date.today().strftime('%Y_%m_%d')}_v0",
        "audit_timestamp": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "scope": "project/dan_personal_cognitive_infrastructure",
        "status": overall_status,
        "inputs": {
            "authority_registry": str(registry_file.relative_to(repo_root)) if registry_file.is_relative_to(repo_root) else str(registry_file),
            "merge_queue": str(merge_queue_file.relative_to(repo_root)) if merge_queue_file.is_relative_to(repo_root) else str(merge_queue_file),
        },
        "summary": summary,
        "checks": {
            "registry_churn_guardrail": registry_result,
            "materialization_guardrail": materialization_result,
        },
        "input_warnings": missing_inputs,
        "next_actions": next_actions,
        "policy_note": "Track-only audit. No automatic mutation.",
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Audit Beads integration boundary guardrails (authority churn + canonical materialization)."
    )
    parser.add_argument("--repo-root", default=str(REPO_ROOT), help="Repository root path")
    parser.add_argument("--registry-file", default=str(DEFAULT_REGISTRY), help="Path to authority registry JSON")
    parser.add_argument("--merge-queue-file", default=str(DEFAULT_MERGE_QUEUE), help="Path to merge queue JSON")
    parser.add_argument("--out-file", default=str(DEFAULT_OUT), help="Output report JSON path")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    registry_file = Path(args.registry_file).resolve()
    merge_queue_file = Path(args.merge_queue_file).resolve()
    out_file = Path(args.out_file).resolve()

    report = _build_report(repo_root, registry_file, merge_queue_file)
    out_file.parent.mkdir(parents=True, exist_ok=True)
    out_file.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
