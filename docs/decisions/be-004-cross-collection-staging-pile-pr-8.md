---
id: be-004
date: 2026-07-28
title: "Cross-collection staging pile (PR 8)"
feature: staging
repo: be
---

# Cross-collection staging pile (PR 8)

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
