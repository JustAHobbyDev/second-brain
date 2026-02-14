#!/usr/bin/env python3
"""
Helper utility to execute the Agent Structural Legibility Benchmark (ASLB).

The script automates:
  * Capturing run metadata (timestamp, git SHA, prompts).
  * Sending the five benchmark prompts to a chat completion model.
  * Persisting raw model responses for auditability.
  * Emitting the canonical ASLB JSON contract plus supporting artifacts.

Typical usage:
    python scripts/run_aslb.py --model gpt-4.1 --run-slug drift-audit \
        --context-file summaries/repo_overview.md

Use --dry-run to generate the folder structure and prompts without
calling a remote model endpoint.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import subprocess
import sys
import textwrap
from pathlib import Path
from typing import Any, Dict, List, Tuple
from urllib import request
from urllib.error import HTTPError, URLError


BASE_SYSTEM_PROMPT = (
    "You are an autonomous structural auditor. Respond only with valid JSON per the user instructions. "
    "Scores must be integers in [0,5]. Choose confidence from ['low','medium','high']."
)


TIER_CONFIG: List[Dict[str, Any]] = [
    {
        "key": "taxonomy",
        "title": "Tier 1: Taxonomy Recoverability",
        "prompt": (
            "Given the corpus context, derive a hierarchical taxonomy of the system. Highlight the top-level "
            "partitions (direction, principles, concepts, patterns/workflows, tools/infra, operations, artifacts, "
            "projects/domains). Return JSON with the following keys:\n"
            "{\n"
            '  "tier": "taxonomy",\n'
            '  "score": 0,\n'
            '  "confidence": "medium",\n'
            '  "taxonomy_tree": "markdown tree",\n'
            '  "analysis": "short rationale",\n'
            '  "evidence": ["path::finding"]\n'
            "}\n"
        ),
    },
    {
        "key": "ontology",
        "title": "Tier 2: Ontology Extraction",
        "prompt": (
            "Infer ontology primitives implied by the corpus: node types, edge types, lifecycle states, invariants. "
            "Return JSON:\n"
            "{\n"
            '  "tier": "ontology",\n'
            '  "score": 0,\n'
            '  "confidence": "medium",\n'
            '  "node_types": ["artifact", ...],\n'
            '  "edge_types": ["derives_from", ...],\n'
            '  "lifecycle_states": ["draft", ...],\n'
            '  "invariants": ["description"],\n'
            '  "analysis": "summary",\n'
            '  "evidence": ["path::finding"]\n'
            "}\n"
        ),
    },
    {
        "key": "governance",
        "title": "Tier 3: Governance Inference",
        "prompt": (
            "Infer rules governing mutation, versioning, determinism, and lineage. Include risks and candidate tests. "
            "Return JSON:\n"
            "{\n"
            '  "tier": "governance",\n'
            '  "score": 0,\n'
            '  "confidence": "medium",\n'
            '  "rules": ["rule statement"],\n'
            '  "risks": ["risk"],\n'
            '  "tests_suggested": ["test idea"],\n'
            '  "analysis": "summary",\n'
            '  "evidence": ["path::finding"]\n'
            "}\n"
        ),
    },
    {
        "key": "direction",
        "title": "Tier 4: Directional Alignment",
        "prompt": (
            "Infer the system's North Star and design charter from artifacts alone. Return JSON:\n"
            "{\n"
            '  "tier": "direction",\n'
            '  "score": 0,\n'
            '  "confidence": "medium",\n'
            '  "north_star_guess": "text",\n'
            '  "charter_guess": "text",\n'
            '  "evidence": ["path::quote"],\n'
            '  "analysis": "summary"\n'
            "}\n"
        ),
    },
    {
        "key": "drift",
        "title": "Tier 5: Drift Detection",
        "prompt": (
            "Compare derived structure to declared direction; identify misalignments, category creep, governance "
            "violations, redundancy, and prioritized refactors/tests. Return JSON:\n"
            "{\n"
            '  "tier": "drift",\n'
            '  "score": 0,\n'
            '  "confidence": "medium",\n'
            '  "misalignments": ["finding"],\n'
            '  "category_creep": ["finding"],\n'
            '  "redundancy": ["finding"],\n'
            '  "refactor_suggestions": ["action"],\n'
            '  "analysis": "summary",\n'
            '  "evidence": ["path::finding"],\n'
            '  "tests_suggested": ["test idea"]\n'
            "}\n"
        ),
    },
]


CONFIDENCE_ORDER = {"low": 0, "medium": 1, "high": 2}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the Agent Structural Legibility Benchmark.")
    parser.add_argument("--model", default=os.getenv("ASLB_MODEL", "gpt-4.1"), help="Chat completion model name.")
    parser.add_argument("--prompt-version", default="v0", help="Prompt set version identifier.")
    parser.add_argument("--run-slug", help="Custom slug for the run directory (defaults to timestamp).")
    parser.add_argument(
        "--output-root",
        default=Path("operations/aslb_runs"),
        type=Path,
        help="Base directory for ASLB run artifacts.",
    )
    parser.add_argument(
        "--context-file",
        action="append",
        default=[],
        help="Path to a text file whose contents are appended to the prompt context. "
        "Pass multiple times to include several files.",
    )
    parser.add_argument(
        "--context",
        default="",
        help="Inline context text appended to every prompt (e.g., repository synopsis).",
    )
    parser.add_argument("--temperature", type=float, default=0.1, help="Model temperature.")
    parser.add_argument("--top-p", type=float, default=0.9, help="Model top-p value.")
    parser.add_argument("--max-tokens", type=int, default=1200, help="Max tokens for each completion.")
    parser.add_argument("--api-base", default=os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1"))
    parser.add_argument("--api-key", default=os.getenv("OPENAI_API_KEY"))
    parser.add_argument("--timeout", type=int, default=120, help="HTTP timeout (seconds).")
    parser.add_argument("--dry-run", action="store_true", help="Skip remote calls and emit placeholder responses.")
    return parser.parse_args()


def run_cmd(*args: str) -> str:
    result = subprocess.run(args, capture_output=True, text=True, check=True)
    return result.stdout.strip()


def load_context(files: List[str], inline_text: str) -> str:
    chunks: List[str] = []
    for file_path in files:
        path = Path(file_path)
        if not path.exists():
            raise FileNotFoundError(f"context file not found: {file_path}")
        chunks.append(f"# File: {path}\n{path.read_text()}")
    if inline_text:
        chunks.append(f"# Inline Context\n{inline_text}")
    return "\n\n".join(chunks).strip() or "<<no additional context provided>>"


def build_prompt(tier_title: str, tier_prompt: str, context: str) -> str:
    return textwrap.dedent(
        f"""
        Agent Structural Legibility Benchmark
        {tier_title}

        Corpus Context:
        {context}

        Instructions:
        {tier_prompt}
        """
    ).strip()


def call_model(
    prompt: str, args: argparse.Namespace
) -> Tuple[str, Dict[str, Any]]:  # returns (content, raw_response_dict)
    if args.dry_run:
        placeholder = {
            "tier": "unknown",
            "score": None,
            "confidence": "low",
            "analysis": "dry run placeholder",
            "evidence": [],
        }
        return json.dumps(placeholder, indent=2), {"dry_run": True, "placeholder": placeholder}

    if not args.api_key:
        raise RuntimeError("API key is required unless running with --dry-run")

    url = args.api_base.rstrip("/") + "/chat/completions"
    body = json.dumps(
        {
            "model": args.model,
            "temperature": args.temperature,
            "top_p": args.top_p,
            "max_tokens": args.max_tokens,
            "messages": [
                {"role": "system", "content": BASE_SYSTEM_PROMPT},
                {"role": "user", "content": prompt},
            ],
        }
    ).encode("utf-8")

    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {args.api_key}",
    }

    req = request.Request(url, data=body, headers=headers, method="POST")
    try:
        with request.urlopen(req, timeout=args.timeout) as resp:
            raw = resp.read()
    except HTTPError as err:
        raise RuntimeError(f"API request failed with status {err.code}: {err.read()}") from err
    except URLError as err:
        raise RuntimeError(f"API request failed: {err.reason}") from err

    payload = json.loads(raw.decode("utf-8"))
    try:
        content = payload["choices"][0]["message"]["content"]
    except (KeyError, IndexError) as exc:
        raise RuntimeError(f"Unexpected API response schema: {payload}") from exc
    return content, payload


def parse_response(content: str, tier_key: str) -> Dict[str, Any]:
    try:
        parsed = json.loads(content)
    except json.JSONDecodeError as exc:
        raise ValueError(f"Model response for tier '{tier_key}' was not valid JSON:\n{content}") from exc
    if parsed.get("tier") != tier_key:
        parsed["tier"] = tier_key
    return parsed


def setup_run_dirs(output_root: Path, run_slug: str) -> Dict[str, Path]:
    timestamp_slug = run_slug or dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d-%H%M%S-aslb")
    run_dir = output_root / timestamp_slug
    subdirs = {
        "run": run_dir,
        "raw": run_dir / "raw",
        "results": run_dir / "results",
        "inputs": run_dir / "inputs",
    }
    for path in subdirs.values():
        path.mkdir(parents=True, exist_ok=True)
    return subdirs


def confidence_floor(results: List[Dict[str, Any]]) -> str:
    lowest_value = min(
        (CONFIDENCE_ORDER.get(item.get("confidence", "low"), 0) for item in results),
        default=0,
    )
    for label, value in CONFIDENCE_ORDER.items():
        if value == lowest_value:
            return label
    return "low"


def dump_json(data: Any, path: Path) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def dump_yaml_or_json(data: Any, path: Path) -> None:
    try:
        import yaml  # type: ignore

        text = yaml.safe_dump(data, sort_keys=False)
    except Exception:
        text = json.dumps(data, indent=2)
    path.write_text(text + "\n")


def main() -> None:
    args = parse_args()
    dirs = setup_run_dirs(args.output_root, args.run_slug)
    context = load_context(args.context_file, args.context)
    git_sha = run_cmd("git", "rev-parse", "HEAD")
    git_status = run_cmd("git", "status", "--short")
    timestamp = (
        dt.datetime.now(dt.timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )

    tier_results: List[Dict[str, Any]] = []
    prompt_hashes: Dict[str, str] = {}

    for index, tier in enumerate(TIER_CONFIG, start=1):
        prompt = build_prompt(tier["title"], tier["prompt"], context)
        prompt_hashes[tier["key"]] = hashlib.sha256(prompt.encode("utf-8")).hexdigest()
        content, raw_payload = call_model(prompt, args)
        parsed = parse_response(content, tier["key"])
        tier_results.append(
            {
                "key": tier["key"],
                "title": tier["title"],
                "prompt": prompt,
                "response_text": content,
                "parsed": parsed,
            }
        )
        raw_path = dirs["raw"] / f"tier_{index}_{tier['key']}.json"
        dump_json(
            {
                "tier": tier["key"],
                "title": tier["title"],
                "prompt": prompt,
                "prompt_hash": prompt_hashes[tier["key"]],
                "model": args.model,
                "response_text": content,
                "parsed": parsed,
                "api_payload": raw_payload,
            },
            raw_path,
        )

    tier_scores = {item["key"]: int(item["parsed"].get("score") or 0) for item in tier_results}
    aggregate_score = sum(tier_scores.values())

    final_contract = {
        "timestamp": timestamp,
        "corpus_ref": git_sha,
        "model": args.model,
        "prompt_set_version": args.prompt_version,
        "tier_scores": tier_scores,
        "aggregate_score": aggregate_score,
        "confidence": confidence_floor([item["parsed"] for item in tier_results]),
        "derived_taxonomy": tier_results[0]["parsed"].get("taxonomy_tree", ""),
        "derived_ontology": {
            "node_types": tier_results[1]["parsed"].get("node_types", []),
            "edge_types": tier_results[1]["parsed"].get("edge_types", []),
            "lifecycle_states": tier_results[1]["parsed"].get("lifecycle_states", []),
            "invariants": tier_results[1]["parsed"].get("invariants", []),
        },
        "governance_inference": {
            "rules": tier_results[2]["parsed"].get("rules", []),
            "risks": tier_results[2]["parsed"].get("risks", []),
            "tests_suggested": tier_results[2]["parsed"].get("tests_suggested", []),
        },
        "direction_inference": {
            "north_star_guess": tier_results[3]["parsed"].get("north_star_guess", ""),
            "charter_guess": tier_results[3]["parsed"].get("charter_guess", ""),
            "evidence": tier_results[3]["parsed"].get("evidence", []),
        },
        "drift_report": {
            "misalignments": tier_results[4]["parsed"].get("misalignments", []),
            "category_creep": tier_results[4]["parsed"].get("category_creep", []),
            "redundancy": tier_results[4]["parsed"].get("redundancy", []),
            "refactor_suggestions": tier_results[4]["parsed"].get("refactor_suggestions", []),
        },
        "notes": "Auto-generated via scripts/run_aslb.py",
        "prompt_hashes": prompt_hashes,
        "git_status": git_status,
        "model_params": {
            "temperature": args.temperature,
            "top_p": args.top_p,
            "max_tokens": args.max_tokens,
        },
    }

    dump_json(final_contract, dirs["results"] / "aslb_result.json")

    tier_summary = []
    for item in tier_results:
        parsed = item["parsed"]
        tier_summary.append(
            {
                "tier": item["key"],
                "score": parsed.get("score"),
                "confidence": parsed.get("confidence"),
                "analysis": parsed.get("analysis"),
                "evidence": parsed.get("evidence"),
            }
        )
    dump_yaml_or_json({"tiers": tier_summary}, dirs["results"] / "tier_scores.yaml")

    run_log = textwrap.dedent(
        f"""
        # ASLB Run Log
        - timestamp: {timestamp}
        - run_dir: {dirs['run']}
        - model: {args.model}
        - prompt_set_version: {args.prompt_version}
        - git_sha: {git_sha}
        - aggregate_score: {aggregate_score}
        - confidence: {final_contract['confidence']}
        - dry_run: {args.dry_run}
        """
    ).strip()
    (dirs["results"] / "run_log.md").write_text(run_log + "\n")

    print(f"ASLB artifacts written to {dirs['run']}")


if __name__ == "__main__":
    try:
        main()
    except Exception as err:  # pragma: no cover - surfacing errors to CLI
        print(f"[ERROR] {err}", file=sys.stderr)
        sys.exit(1)
