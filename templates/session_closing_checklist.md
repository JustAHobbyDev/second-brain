# Session Closing Checklist

This checklist converts a working session into durable infrastructure.

Use this at the end of every meaningful Codex or ChatGPT session.

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

In Codex or ChatGPT, say:

“Emit a graph-ready session artifact using my standard template.”

Ensure it includes:

* High-level summary
* Key decisions
* Changes made
* Open questions
* Links to projects
* Links to principles
* Links to patterns
* Tools touched
* Notes for future agents

---

## 3. Verify Structural Integrity

Before saving, check:

* ID follows format:
  artifact/codex_session_YYYY_MM_DD_slug
* created_at timestamp exists
* links.projects contains at least one project
* No empty arrays where meaningful data exists
* IDs referenced actually exist in scenes/

If unsure, fix before saving.

---

## 4. Save the Artifact

Save to:

```bash
sessions/<tool>/YYYY-MM-DD-slug.json
```

Example:

```bash
sessions/codex/2026-02-11-trading-pipeline.json
```

The filename slug should roughly match the artifact ID.

---

## 5. Update Index (Optional but Recommended)

Open:

sessions/<tool>/index.json

Append the artifact ID.

Example:

```json
{
    "codex_sessions": [
        "artifact/codex_session_2026_02_11_trading_pipeline"
    ]
}

```

This makes traversal easier later.

---

## 6. Sanity Check: Does This Reduce Future Ramp-Up?

Ask yourself:

“If I lost all context except this JSON file, could I resume?”

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

The session is now part of your second brain.

Ephemeral thinking → structured artifact → graph node → infrastructure.

