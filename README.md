# 🧠 Second Brain — Graph-Ready Personal Knowledge Infrastructure

This repository contains a portable, graph-friendly, agent-compatible second brain.

This is not a note-taking system.

It is structured cognitive infrastructure designed so that:

* You can resume work reliably.
* AI assistants can reason across artifacts.
* Future agents can traverse and extend your knowledge.
* The architecture survives tool churn.

Architecture is stable. Tools are replaceable.

---

# Purpose

This system exists to:

* Preserve thinking, not just conclusions.
* Encode decisions and open questions.
* Link principles, patterns, tools, and projects.
* Emit structured artifacts that AI can traverse.

This repository is designed around the idea that:

* Sessions produce artifacts.
* Artifacts link into a graph.
* The graph becomes infrastructure.

---

# Repository Layout

```bash
.
├── meta
├── operations
├── profiles
├── graph
├── prompts
├── scenes
├── scripts
├── sessions
│   ├── chatgpt
│   └── codex
├── templates
└── tools
```

---

## Meta

* [Spec Spec v0](meta/SPEC_SPEC_v0.md)
* [Meta Workflow Execution Spec v0](meta/META_PROGRAM_SPEC_v0.md)
* [Scene Graph Integration Spec v0](meta/SCENE_GRAPH_INTEGRATION_SPEC_v0.md)
* [Prompt Lineage Ontology Spec v0](meta/PROMPT_LINEAGE_ONTOLOGY_SPEC_v0.md)
* [Generate Project History Operation v0](operations/generate_project_history_v0.md)
* [Incorporate Scene Into Graph Operation v0](operations/incorporate_scene_into_graph_v0.md)
* [Dan Cognitive Operating Model Template v0](profiles/dan_cognitive_operating_model_v0.md)
* [Session Closing Checklist](templates/session_closing_checklist.md)
* [Graph Scene Schema v0](scenes/_schemas/graph_scene_v0.schema.json)
* [Phase Event Schema v0](scenes/_schemas/phase_event_v0.schema.json)
* [Phase History Schema v0](scenes/_schemas/phase_history_v0.schema.json)
* [Scene Graph Ingest Script v0](tools/sb_graph_ingest_v0.sh)
Graph export is optional and experimental; scenes remain the source of truth.

---

## scenes/

A scene is a coherent knowledge chunk.

A scene file may contain:

* artifact nodes
* project nodes
* pattern nodes
* principle nodes
* concept nodes
* tool nodes
* edges connecting them

Scene files are mixed-type by design.

Examples:

* four_principles_second_brain.scene.json
* dan_codex_meta_workflow_v1.scene.json
* kalshi_15m_btc_pipeline.scene.json

A scene represents one conceptual unit.

File location does not determine node type.

Node ID determines type.

---

## sessions/

Sessions contain closure artifacts from working conversations.

Each meaningful Codex or ChatGPT session should end with a structured JSON artifact.

Directory structure:

sessions/

* codex/
* chatgpt/

Naming convention:

YYYY-MM-DD-slug.json

Example:

2026-02-11-trading-pipeline.json

Each file contains one artifact node.

These are durable state snapshots.

---

## templates/

Contains reusable schemas.

Example:

codex_session_template.json
session_closing_checklist.md

This defines the structure for session closure artifacts.

---

## graph/

Optional.

Used if you later merge all nodes into a single canonical graph file.

Not required at this stage.

---

# Core Conventions

## 1. IDs Are Canonical

Every node has an ID in the form:

type/identifier

Examples:

artifact/codex_session_2026_02_11_trading_pipeline
pattern/dan_codex_meta_workflow_v1
project/dan_personal_cognitive_infrastructure
principle/architecture_portable_tools_not
tool/codex

IDs are stable.

Folders are not.

---

## 2. Scene-Based Architecture

Files represent scenes, not types.

A single scene file may contain:

* a project
* a pattern
* related principles
* edges between them

This is intentional.

Do not split nodes across files just to satisfy folder symmetry.

Architecture > aesthetics.

---

## 3. Session Closing Ritual

Every meaningful Codex session should end with:

1. Request a graph-ready summary using the session template.
2. Save the JSON file into:

```bash
sessions/codex/YYYY-MM-DD-slug.json
```

3. Ensure links reference:

   * relevant projects
   * principles
   * patterns
   * tools
   * related artifacts

This converts ephemeral conversation into infrastructure.

---

## 4. Linking > Folders

Folders help humans navigate.

Links help agents reason.

When in doubt:

Add links, not directories.

---

# Workflow

## Starting Work

* Identify the project ID.
* Reference relevant principle IDs.
* Reference relevant pattern IDs.
* Begin session.

## Ending Work

* Emit structured artifact.
* Save under sessions/.
* Link appropriately.

## Resuming Work

* Open the most recent session artifact.
* Provide it to AI.
* Ask for next steps.

---

# System Principles

This repository embodies:

Architecture is portable, tools are not.
Principles scale better than rigid rules.
If the agent builds it, the agent can maintain it.
Your system can be infrastructure, not just a tool.

These are encoded into how sessions, scenes, and artifacts are structured.

---

# What This Is Not

This is not:

* A productivity app.
* A markdown note vault.
* A folder taxonomy.
* A static archive.

It is:

A structured, evolving graph of cognitive artifacts.

---

# Growth Path

This system can later expand into:

* A graph database.
* A vector index.
* Automated ingestion.
* CLI tools.
* Agent-driven querying.
* Infrastructure-level APIs.

None of that is required yet.

The current focus is architectural discipline.

---

# Mental Model

Sessions produce artifacts.
Artifacts link into scenes.
Scenes compose into a graph.
The graph becomes infrastructure.

---

# Author

Dan — building long-horizon, agent-compatible cognitive infrastructure.

This repository reflects current architecture and is expected to evolve.
