# Pub/Sub Bus Spec v0

## Status
- `status`: draft
- `mode`: track-only
- `activation_rule`: keep `coord_claims.md` as primary coordination surface for now
- `migration_trigger`: consider moving to this bus when there are at least 3 recurring consumers

## Purpose
Define a minimal file-native pub/sub pattern that keeps coordination deterministic and auditable without introducing external infrastructure.

## Scope
- Local repository workflows only
- Append-only event log
- Consumer-owned offsets
- No global lock manager
- No hard-gate behavior in v0

## Canonical Storage
- `events_file`: `state/pubsub/events_v0.ndjson`
- `offsets_dir`: `state/pubsub/offsets/`
- `offset_file_pattern`: `state/pubsub/offsets/<consumer>.json`

## Event Contract (required fields)
Each line in `events_v0.ndjson` is one JSON object.

```json
{
  "event_id": "evt_20260216T111200Z_ab12cd34ef56",
  "ts": "2026-02-16T11:12:00Z",
  "topic": "coord.claim",
  "scope": "scene/taxonomy_core.md",
  "actor": "gray_and_orange",
  "payload": {
    "path": "scene/taxonomy_core.md",
    "intent": "edit"
  },
  "ttl_s": 600,
  "idempotency_key": "coord.claim|scene/taxonomy_core.md|gray_and_orange|2026-02-16T11:12:00Z"
}
```

## Topic Set v0
- `coord.claim`
- `coord.release`
- `closeout.created`
- `gate.status_changed`

## Delivery Semantics
- Append-only log, at-least-once delivery model.
- Consumers track their own read cursor in `<consumer>.json`.
- Consumers must deduplicate with `idempotency_key` (or `event_id`) if needed.
- Event expiration is advisory via `ttl_s`; expired events are filtered by consumers, not deleted.

## Consumer Offset Contract

```json
{
  "consumer": "coord_watcher",
  "events_file": "state/pubsub/events_v0.ndjson",
  "next_line": 42,
  "updated_at": "2026-02-16T11:12:30Z"
}
```

`next_line` is 1-based and points to the next unread line.

## Bootstrap/Preflight Behavior
- On startup, consumer reads the offset file if present; otherwise starts at line `1`.
- Consumer reads from `next_line` to end of file, applies topic and expiry filters, emits selected events, then advances offset.
- No lock is required in v0.

## Entropy Rationale
- Single canonical event surface for signaling.
- Reproducible replays from `events_v0.ndjson` plus offsets.
- Avoids ad-hoc cross-file coordination as fan-out grows.

## Adoption Guidance
- Keep current coordination model (`coord_claims.md`) unless operational demand justifies pub/sub.
- Promote this v0 bus from draft when at least 3 recurring consumers are active and fan-out logic is duplicated across workflows.
