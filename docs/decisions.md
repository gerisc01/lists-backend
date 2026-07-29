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

## 2026-07-29 — Recurrence as a rule + ghost materialization (PR 12, shadow)

**Context**: The legacy recurring model (2026-04-20 ADR above) spawns a real child item per
occurrence. The catalog/placement refactor (design.md §2.5) replaces it with a *rule* that
keeps one live occurrence present per period, draining into staging like any placement. PR 12
is the first slice of a 2–3 PR arc.

**Decision**:
- The recurrence rule folds into the existing `item.scheduling` object as
  `scheduling.recurrence`, validated by a new `Recurrence` type (`src/type/recurrence.rb`) via
  the same `type_match?` mechanism as `Scheduling`/`Resolution`/`Status` — **no new top-level
  item field**. Rule shape: `{cadence, interval, mode, anchor, collection_id, active?,
  start_date?}`.
- Untouched occurrences are **ghosts**, computed for the visible week by a pure
  `occurrences_for_week` primitive (`src/actions/occurrences.rb`) modeled on `reconcile`
  (injectable date, logic-here/trigger-separate) and, like `reconcile`, **not registered** in
  `item_actions.rb` — it is a read, not a mutation. A `Placement` persists only once an
  occurrence is **touched**; a persisted placement whose period (immutable `origin_date`, else
  `date`) matches a due-week **suppresses** that week's ghost. Dedup reuses existing placement
  fields — **no Placement schema change**.
- Invariant machinery is pure compute over the rule: at most one live occurrence per rule per
  week (the most recent due-week ≤ the target week); an untouched occurrence carries forward
  each week until the next comes due, then auto-expires (older occurrences are simply never
  surfaced — no aggregation). A carried floating or slipped fixed-day occurrence re-floats
  (mirroring `reconcile`'s carry of a lapsed dated task), keeping its origin as the anchor.
- **Scope**: absolute weekly, `floating` + `fixed-day` anchoring. **Deferred (PR 13/14)**:
  relative cadence, monthly/date/week-phase anchoring, `end_date`, occurrence splitting, "just
  this once" overrides, the REST wiring + FE (rule editor, re-enabling the frozen
  `TodoDatePicker` checkbox, touch-persists-a-placement), and removal/migration of the legacy
  parent-child path.
- The legacy parent-child model + `/api/dates/:day/recurring` routes are **left dormant and
  untouched**; the new rule model shadows them (nothing reads `occurrences_for_week` yet).

**Rationale**: Folding into `scheduling` matches the pre-designed home (the field was made an
object for exactly this) and avoids a second recurrence field. Ghost-not-store keeps the
cache win of the old pre-dated-children approach without spawning rows for occurrences never
touched. Reusing `origin_date` for dedup keeps PR 12 free of any Placement migration; if
period-matching proves insufficient, a `rule_item_id`/period stamp can be added when the
touch-persists path lands in PR 13. Shadow-first (like PR 1 / PR 5a / PR 9a) lets the model be
proven by request-specs before anything user-facing depends on it.

---

## In Progress

*(Add notes here when starting a work session — what you're building, what's broken, what's next)*
