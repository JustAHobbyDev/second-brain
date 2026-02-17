# Session Closing Checklist

Status: Legacy (deprecated default in `project/second-brain`)

This checklist is for controlled migration/backfill only.

Default policy is to rely on git + `reports/checkpoints/*` for provenance.

---

## 1. Decide: Is This Session Worth Closing?

Close the session if:

* A design changed.
* A decision was made.
* Architecture evolved.
* A new pattern emerged.
* Open questions were clarified.
* You would want to resume this later.

If none of those happened, do not emit an artifact.

---

## 2. Request Graph-Ready Summary

In your current assistant/tool, say:

"Emit a graph-ready session artifact using my standard template."

Ensure it includes:

* `artifact_id`, `session_date`, `llm_used`
* `summary`, `key_decisions`, `open_questions`, `next_steps`
* `prompt_lineage` as array objects (`role`, `ref`/`summary`)
* `resumption_score` (0-10) + `resumption_notes`
* `project_links`, `principle_links`, `pattern_links`, `tool_links`, `related_artifact_links`
* `thinking_trace_attachments`

---

## 3. Verify Structural Integrity

Before saving, check:

* `artifact_id` follows format:
  `artifact/{llm}_{YYYY_MM_DD}_{kebab-case-3-to-6-word-slug}`
* `llm_used` is populated and matches `artifact_id` prefix
* `prompt_lineage` has at least one entry with `role` + source context (`ref` or `summary`)
* resumption_score is populated (0-10)
* resumption_notes is populated
* `session_date` exists and is `YYYY-MM-DD`
* `project_links` contains at least one project
* `principle_links` has at least 2 entries when relevant (or explain why not)
* `pattern_links` has at least 1 entry when relevant (or explain why not)
* No empty arrays where meaningful data exists
* IDs referenced actually exist in scenes/
* Open questions are numbered and actionable

If unsure, fix before saving.

---

## 4. Save the Artifact (legacy only)

Save to:

```bash
sessions/<assistant_or_tool>/YYYY-MM-DD-slug.json
```

Example:

```bash
sessions/chatgpt/2026-02-11-trading-pipeline.json
```

The filename slug should roughly match the artifact ID.

---

## 5. Update Index (Legacy Mode)

Legacy policy:
* Update `sessions/<assistant_or_tool>/index.json` only during controlled backfill/migration runs.

Target index shape:

```json
{
  "tool": "chatgpt",
  "artifacts": [
    {
      "id": "artifact/chatgpt_2026_02_11_trading-pipeline",
      "date": "2026-02-11",
      "resumption_score": 8,
      "summary_snippet": "Established scene-based second-brain architecture and closure ritual."
    }
  ],
  "last_updated": "2026-02-15T00:00:00Z"
}
```

This preserves historical continuity for legacy artifacts.

---

## 6. Sanity Check: Does This Reduce Future Ramp-Up?

Ask yourself:

"If I lost all context except this JSON file, could I resume?"

If no:

Improve the summary.

---

## 7. Confirm Links to Architecture

Make sure at least one of these is referenced:

* A project node
* A principle node
* A pattern node

Sessions without architectural links become isolated memory.

Sessions with links become infrastructure.

---

# Done

The legacy session artifact is now archived.

Canonical infrastructure should still be captured in `scenes/` with stable IDs and source refs.
