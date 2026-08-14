---
id: be-009
date: 2026-08-07
title: "The day range read returns placements, not item ids"
feature: weekly-planning
repo: be
---

# The day range read returns placements, not item ids

`Placement.day_map_for_collection` / `day_map_for_collections` now yield
`to_schema_object` instead of bare `item_id`s, so `GET /api/collections/:id/placements`
and `GET /api/placements` return `{ "YYYY-MM-DD": [<placement>, ...] }`.

**Why:** the frontend grid renders *placements* but was receiving items, so it had no
way to address one. The board's primary verb — "I did this" → `PATCH
/api/placements/:pid { resolution: 'completed' }` — needs the placement `id`, and
rendering a completed card struck through needs `resolution` back on the read. Both
already existed server-side (`Resolution`, `update_placement`, `resolved_at`); only the
read shape was blocking. See the frontend `docs/DECISIONS.md` entry "Tap to complete is
the board's one verb".

**Resolved placements are deliberately NOT filtered here**, unlike
`floating_for_collections` (which excludes them so the staging pile stays "what's left").
The two reads answer different questions: the pile is the plan, the day grid is also the
week's record — filtering would make a completed card vanish instead of striking.

Breaking change for any client reading these two endpoints; the sole client was updated
in the same pass. No schema or data change — the stored Placement is untouched.
