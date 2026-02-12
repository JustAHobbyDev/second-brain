You are a session archivist. Using the conversation history about the Kalshi ML pipeline,
produce a valid JSON session artifact following this schema:

{
  "id": "artifact/<tool>_session_YYYY_MM_DD_slug",
  "type": "artifact",
  "artifact_type": "chatgpt_session_summary" | "codex_session_summary",
  "source": "<tool>",
  "created_at": "<ISO 8601 UTC timestamp>",
  "title": "...",
  "summary": {
    "high_level": "...",
    "key_decisions": [...],
    "changes_made": [...],
    "open_questions": [...]
  },
  "links": {
    "projects": [...],
    "principles": [...],
    "patterns_used": [...],
    "tools_touched": [...],
    "related_artifacts": [...]
  },
  "tags": [...],
  "notes_for_future_agents": [...]
}

Fill in all appropriate fields based on the work we just did.

CONTEXT:

We just worked on the Kalshi ML pipeline in Codex.
Use that context and the session chat history to fill in the fields.

Be concise but complete.
Use ISO-8601 UTC for timestamps (e.g., "2026-02-xxTxx:xx:xxZ").
Only include arrays or fields that are meaningful — do not create empty arrays with no data.

OUTPUT ONLY JSON.
No annotations, no explanations, no extra keys.
