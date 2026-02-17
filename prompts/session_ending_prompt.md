Legacy mode only: you are closing this [LLM_NAME e.g. Codex / o1 / ChatGPT] session artifact for migration/backfill.

Output ONLY valid JSON, no markdown, no explanations, no extra text outside the object. The JSON must exactly match this structure (do not add/remove top-level keys; use empty arrays/strings when no value):

{
  "artifact_id": "artifact/[llm_lowercase]_[YYYY_MM_DD]_[kebab-case-3-to-6-word-slug]",
  "session_date": "YYYY-MM-DD",
  "llm_used": "[codex | o1 | chatgpt | claude | gemini | etc.]",
  "project_links": ["project/..."],
  "principle_links": ["principle/..."],
  "pattern_links": ["pattern/..."],
  "tool_links": ["tool/..."],
  "related_artifact_links": ["artifact/..."],
  "summary": "One tight paragraph summarizing key progress, decisions, outputs, and state at close.",
  "key_decisions": ["Bullet-style concrete decision 1", "Decision 2"],
  "open_questions": ["1. Unresolved item with context/owner if known", "2. Next question..."],
  "next_steps": ["Concrete next action 1 (who/what/when if relevant)"],
  "thinking_trace_attachments": ["Important preserved raw output/code/reasoning chain as string or reference"],
  "prompt_lineage": [
    {"role": "system", "ref": "prompts/filename.md or brief description", "summary": "optional one-liner purpose"},
    {"role": "user", "summary": "key user prompt intent"}
  ],
  "resumption_score": 7,
  "resumption_notes": "What context/links/files must be loaded first to resume effectively"
}

Rules you MUST follow:
- artifact_id MUST use the exact format above; invent a short, descriptive kebab-slug if needed.
- Link aggressively: aim for >=2-3 principle_links and >=1-2 pattern_links minimum when relevant.
- Use ONLY existing canonical IDs in links unless explicitly proposing a new one (then note it in summary/open_questions).
- resumption_score must be >=6 for a passing closeout; if <6, treat as checklist failure and improve artifact quality before emitting.

Before outputting JSON, self-verify against this checklist:
- [ ] All IDs follow type/identifier format
- [ ] >=2 principle links (or justified why not)
- [ ] Open questions are numbered and actionable
- [ ] No syntax errors, valid JSON only
- [ ] Strong agent resumability (links, score, notes)
- [ ] resumption_score >= 6

If any checklist item fails, fix it internally before emitting JSON.

Output the JSON now.
