# Agent Ontology Summary Prompt Template (v0.1)

Use this template when you need Codex (or another agent) to emit a concise, versioned summary of the Agent Ontology v0.1 plus future-roadmap context.

---

## Context

- Artifact: Agent Ontology v0.1 (minimal world-model schema for autonomous agents)
- Goals:
  1. Provide a human/M2M-readable summary of the ontology.
  2. Emit an explicit roadmap for the next version (v0.2+), starting with multi-agent primitives.
  3. Record a versioned changelog snippet for traceability.

Reference principles:
- Implementation-first
- Traceable (log + replay)
- Stack-agnostic
- Versioned

Core entity set (seed):
- Agent, Task, Goal, Plan/PlanStep, Action, Memory, Artifact, Observation, OpenQuestion, Assumption, Risk, Criterion

Execution loop: `Observe → Orient → Plan → Act → Evaluate → Store → Reflect`

Explicit omissions in v0.1: Multi-agent coordination, belief states, temporal reasoning, formal graph semantics (defer to v0.2+ roadmap).

---

## Prompt (Fill Braces as Needed)

```
You are documenting the Agent Ontology v0.1 for Codex workflows.

Using the context provided below, produce:
1. A succinct text summary of Agent Ontology v0.1.
2. A next-version roadmap (prioritize multi-agent primitives, then belief/commitment tracking, then temporal entities).
3. A changelog entry for the current release (v0.1) following the format in the Output section.

Context:
- Purpose: Minimal schema for agent world models covering tasks, plans, memory, artifacts, constraints, execution loops.
- Design Principles: Implementation-first; Traceable (log + replay); Stack-agnostic; Versioned.
- Core Entities: Agent; Task; Goal; Plan; PlanStep; Action; Memory; Artifact; Observation; OpenQuestion; Assumption; Risk; Criterion.
- Execution Loop: Observe → Orient → Plan → Act → Evaluate → Store → Reflect.
- Known Omissions (target for v0.2+): Multi-agent coordination, belief states, temporal reasoning, formal graph semantics.
- Usage: Publish JSON schema publicly; version and iterate.

Output requirements:
- Follow the “Output Format” section verbatim.
- Keep each bullet under 30 words when possible.
- Note any open TODOs or dependencies in the roadmap.
```

---

## Output Format

```
### 1. Title
Agent Ontology v0.1 (or current version)

### 2. Purpose
<One sentence describing the ontology’s intent.>

### 3. Summary
- Entity Focus: <short bullet list>
- Execution Loop: Observe → Orient → Plan → Act → Evaluate → Store → Reflect
- Design Principles: Implementation-first; Traceable; Stack-agnostic; Versioned

### 4. Next-Version Roadmap (v0.2+)
1. Multi-agent primitives (coordination roles, shared memory, conflict resolution)
2. Belief / commitment model (assumptions, evidence, verification)
3. Temporal semantics (timelines, commitments, scheduling edges)
4. Graph formalization (typed edges + constraints) — optional if capacity allows

### 5. Changelog
- v0.1 — Initial minimal schema (entities: Agent, Task, Plan, Memory, Artifact, Observation, OpenQuestion, Assumption, Risk, Criterion); execution loop formalized; omissions documented.

### 6. TODO / Dependencies
- Publish JSON schema
- Define roadmap owner + cadence
```

Feel free to embed this template in higher-level specs or automation flows; update version tags when iterating beyond v0.1.
