# STRUCTURAL_AUDIT_RUNBOOK.md

Operational checklist for running the Agent Structural Legibility Benchmark (ASLB) defined in `STRUCTURAL_AUDIT_SPEC_v0.md`.

---

## 1. Purpose
- Provide a deterministic procedure for executing ASLB runs.
- Ensure every run emits comparable artifacts (scores, prompts, evidence).
- Keep drift detection loops lightweight enough to run monthly or on-demand.

---

## 2. Pre-Run Checklist
1. **Corpus snapshot**
   - Confirm working tree is clean or record git status.
   - Capture `git rev-parse HEAD` as `corpus_ref`.
2. **Context artifacts**
   - North Star + Design Charter docs easily accessible.
   - Gather latest scene/spec diffs if running post-refactor.
3. **Model + runtime**
   - Choose model (`model` field) and note provider endpoint + temperature (prefer deterministic or low variance).
4. **Prompt set**
   - Default `prompt_set_version = "v0"` (see Section 5 for text).
   - If editing prompts, version them and store diff alongside run output.
5. **Output location**
   - Create run folder: `operations/aslb_runs/YYYY-MM-DD-slug/` (mkdir if needed).
   - Pre-create `inputs/`, `raw/`, `results/` subfolders for organization.

---

## 3. Execution Flow
1. **Kickoff log** (`results/run_log.md`)
   - Record timestamp (ISO-8601), operator, reason for run (drift check, refactor gate, etc.).
2. **Prompt evaluations** (per tier)
   - Use Section 5 prompts.
   - Provide corpus context: repo summary, key files, or zipped snapshots if external agent.
   - Save model responses verbatim in `raw/tier_<n>_<model>.json` (or `.md`).
3. **Score derivation**
   - Operator reads responses and scores each tier 0–5 per spec.
   - Note evidence paths + rationale in `results/tier_scores.yaml` to keep structured.
4. **Aggregate computation**
   - Calculate aggregate = sum of tier scores.
   - Assign aggregate band (Fragmented / Structured / Agent-comprehensible / Self-reflective) per spec.
5. **Deterministic Record**
   - Fill JSON contract from spec and save to `results/aslb_result.json`.
   - Include additional fields: `prompt_hashes`, `model_params`, `operator` if helpful.
6. **Diff + Drift analysis**
   - Compare to previous run (if exists) via script or manual diff, capture insights in `results/drift_notes.md`.

---

## 4. Scoring Guidance Snapshot
- Never up-score on uncertainty; instead, add `confidence: low`.
- If two operators disagree, log both scores + rationale, then reconcile.
- Maintain `results/evidence/` with snippets or hashes for every major claim so future agents can audit.

---

## 5. Prompt Templates (v0)
Use verbatim unless you create a new prompt_set_version.

### Taxonomy Prompt
```
You are auditing a structured cognitive repository. From the provided corpus artifacts, derive a hierarchical taxonomy of the system. Highlight top-level partitions (direction, principles, concepts, patterns/workflows, tools/infra, operations, artifacts, projects/domains). Output a tree structure plus short rationale.
```

### Ontology Prompt
```
Infer the ontology primitives implied by this corpus: node types, edge types, lifecycle states, invariants. Provide concrete examples for each and cite artifact paths or IDs when possible.
```

### Governance Prompt
```
Infer the rules governing mutation, versioning, determinism, and lineage in this corpus. Express rules as testable statements, note associated risks, and propose checks or tests that would enforce them.
```

### Direction Prompt
```
Infer the North Star and design charter of this system strictly from artifacts. Summarize the intent, what success looks like, and what the system explicitly avoids. Cite evidence for each claim.
```

### Drift Prompt
```
Compare the derived structure to the declared North Star and design charter. Identify misalignments, category creep, governance violations, redundancy, and refactor/test recommendations. Prioritize findings.
```

---

## 6. Output Packaging
1. `results/aslb_result.json` (canonical contract).
2. `results/run_log.md` (timeline, operator notes).
3. `results/tier_scores.yaml` (tier-by-tier rationale + confidence).
4. `raw/` folder with verbatim model outputs and prompt inputs.
5. Optional: `reports/aslb_summary.md` for stakeholder-friendly narrative.

Archive the entire run folder under `operations/aslb_runs/` and reference it in future sessions.

---

## 7. Post-Run Actions
- If aggregate < 16 or any tier < 3, open issues or TODO scenes referencing drift findings.
- Update `README.md` or relevant specs if governance or direction statements changed.
- Consider running ASLB on a second model to verify stability; attach comparison notes.
- Schedule next run (monthly cadence baseline) and log in `OPEN_QUESTIONS.md` if outstanding risks remain.

---

## 8. Automation Hooks (future)
- Wrap steps 2–5 in a script (e.g., `scripts/run_aslb.py`) that:
  - Captures repo state
  - Runs prompt set via API
  - Assembles JSON contract
- Integrate with CI to fail builds when ASLB thresholds are not met (aggregate < 16 or tier < 3).

