# Second Brain Taxonomy

Version: v0
Status: Experimental
Generated On (UTC): 2026-02-14T06:26:02Z
Source Scenes:
- `scenes/dan_personal_cognitive_infrastructure.scene.json`
- `scenes/dan_codex_meta_workflow_v1.scene.json`
- `scenes/four_principles_second_brain.scene.json`
- `scenes/second_brain_toolchain.scene.json`

## Hierarchical Taxonomy

```text
Second Brain (project/dan_personal_cognitive_infrastructure)
├── 1. Direction
│   ├── North Star
│   │   └── Durable AI-native knowledge system with compounding intelligence
│   └── Design Charter
│       ├── Transform raw information into structured, semantically linked knowledge
│       ├── Not a note-taking system
│       └── Designed to:
│           ├── Convert conversations/research/execution into durable knowledge objects
│           ├── Encode relationships explicitly
│           ├── Enable graph traversal and semantic transformation
│           ├── Support autonomous + collaborative AI reasoning
│           └── Improve decision-making and project execution over time
├── 2. Principles
│   ├── Architecture is portable, tools are not
│   ├── Principles over rules
│   ├── If agent builds it, agent can maintain it
│   └── System as infrastructure
├── 3. Core Concepts
│   ├── Capture -> structure -> store -> retrieve
│   ├── Second brain as infrastructure
│   ├── Session-based processing
│   ├── Always-on processing
│   ├── Agent maintainability
│   ├── Writer-critic loop
│   ├── Community as pattern library
│   └── AI as implementation muscle
├── 4. Workflow Patterns
│   ├── Dan Codex + ChatGPT meta-workflow (v1)
│   ├── Notion + Zapier + Claude/ChatGPT
│   ├── Discord + Obsidian + MacWhisper
│   ├── Claude computer-use + Obsidian + TypeScript agent
│   ├── Meta-agent with multiple coding assistants
│   ├── Postgres + vector DB + graph DB infrastructure
│   ├── Notion mobile inbox + scheduled Claude
│   ├── Slack + YAML + Claude Code session processing
│   └── Zapier Slack -> Claude -> Notion classifier
├── 5. Capability Stack (Tools)
│   ├── Agent/LLM interfaces: Codex, ChatGPT, Claude, Claude Code, Copilot, Goose
│   ├── Capture surfaces: Slack, Discord, Google Chat
│   ├── Knowledge stores: Obsidian, YAML files, Notion
│   ├── Automation/orchestration: Zapier, Make
│   ├── Data/graph substrate: PostgreSQL, vector DB, Neo4j
│   └── Runtime/utilities: Chrome, Claude Co-Work
├── 6. Operational Toolchain
│   ├── Second-brain CLI (sb)
│   │   └── Source: tools/sb.py
│   ├── Session index updater
│   │   └── Source: scripts/update_index.py
│   └── Concept: session index maintenance
└── 7. Key Artifacts
    ├── Four principles case-study artifact
    └── Second-brain commit/index toolchain map artifact
```

## Notes
- This taxonomy is conceptual and intentionally technology-agnostic at the top levels.
- Tools live lower in the hierarchy than principles and concepts.
- Project direction (North Star + Design Charter) is the root governance context for all patterns and tool choices.

## Canonical Project ID Policy
- Primary canonical project ID: `project/dan_personal_cognitive_infrastructure`
- Deprecated project alias: `project/second_brain_build`
- Alias relation: `project/second_brain_build` -> `project/dan_personal_cognitive_infrastructure`

### Alias Map (v0)
```json
{
  "project/second_brain_build": "project/dan_personal_cognitive_infrastructure"
}
```

- Legacy scenes/artifacts remain unchanged for historical truth.
- New links should use `project/dan_personal_cognitive_infrastructure`.
