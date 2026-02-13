Meta Program Prompt 30: Closeout Template Integration
Version: v0
Status: Experimental
Inputs:
- `templates/` existing closeout/session templates
- `README.md` or repo index convention
- `meta/` and `operations/` artifacts

Task:
- Integrate closeout-template references into the meta workflow index.
- If no suitable closeout template exists, create a minimal versioned template artifact with Version/Status/Inputs and deterministic checklist ordering.
- Add/update README (or index convention) with links to meta spec, operation spec, profile template, and phase schemas.

Determinism:
- Index links should use stable ordering: meta -> operations -> profiles -> schemas.
- Checklist items should remain in fixed order across reruns.
