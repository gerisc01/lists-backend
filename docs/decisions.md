# Decisions

Running log of design decisions and current in-progress work. Update this at the end of any session with significant changes.

Format: `## YYYY-MM-DD — Title` then context, decision, and rationale.

---

## 2026-04-20 — Dates grouped by collection, not list

**Context**: Date queries (`/api/dates/:day/:collection/items`) need to aggregate items across many lists in a single view (e.g., a weekly planner pulling from multiple lists).

**Decision**: The dates API groups items by collection rather than by list.

**Rationale**: A user's "today view" or "week view" spans all their lists within a collection. Grouping by list would require multiple calls or a separate aggregation layer.

---

## 2026-04-20 — Recurring events use parent-child model

**Context**: Recurring events need to exist as real items on individual dates (for editing, completion tracking, etc.) but also need to be linked to their spec.

**Decision**: A parent item holds the recurrence spec and children IDs. Each occurrence is a child item referencing the parent. All are tagged with the `recurring-item` template.

**Rationale**: Avoids virtual/computed items, keeps the existing item model unchanged, and allows individual occurrences to be modified or completed independently.

---

## 2026-04-20 — Soft deletes

**Context**: Mobile/offline sync clients need to know what was deleted since their last sync.

**Decision**: `delete!` sets `deleted: true` on the record rather than removing the file. `list({since:, include_deleted: true})` returns deleted records so clients can remove them locally.

**Rationale**: Without soft deletes, a client that syncs infrequently has no way to learn about deletions.

---

## 2026-07-28 — Cross-collection staging pile (PR 8)

The weekly planner's floating-placement pile spans a *set* of collections, not one.
Added `Placement.floating_for_collections(ids)` + `GET /api/placements/floating?collections=`
(the pile) and `Placement.day_map_for_collections(ids, start, end)` +
`GET /api/placements?collections=&start=&end=` (the mixed grid). Both are single
memory-cached `list` scans, consistent with the other placement queries — no new index.
The floating response merges a **derived** `one_off` flag (`!item_has_shelf_home?`, the
existing predicate shared by `reconcile`/`delete_placement`) so the client can bucket
board-born one-offs; no new stored field. `to_schema_object` already emits `collection_id`,
so grouping-by-source needed no response change. Binding still keeps a placement's source
`collection_id` (no re-home), so carry-forward re-floats a lapsed item back into its origin
collection. See the frontend `docs/DECISIONS.md` PR 8 ADR for the full rationale.

---

## In Progress

*(Add notes here when starting a work session — what you're building, what's broken, what's next)*
