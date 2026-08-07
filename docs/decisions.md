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

## 2026-07-29 — Recurring endpoints + the touch=>real seam (PR 13)

**Context**: PR 12 landed the recurrence rule + pure `occurrences_for_week` materializer shadow
(nothing read it, nothing persisted). PR 13 makes the model API-complete so the FE cutover
(PR 14) has stable endpoints, kept purely additive (backend-only).

**Decision**:
- Added `GET /api/occurrences?collections=&week_start=` (wraps `occurrences_for_week`) and
  `POST /api/items/:id/occurrences` (`{collection, period_start, date?}`) in
  `src/api/occurrences_api.rb`.
- The write is the **touch => real** seam: `materialize_occurrence(item_id, collection_id,
  period_start, date=nil)` (`src/actions/materialize_occurrence.rb`) persists a ghost as a
  `Placement` stamped **`origin_date = period_start`** (the occurrence's due-week), `date` =
  the bound day or nil (floating). Idempotent on `(item, collection, origin_date == period_start)`.
- Stamping `origin_date = period_start` is the one load-bearing choice, and needs **no
  Placement schema change**: the PR 12 dedup (`occurrence_touched?`) already matches a placement
  whose `origin_date`/`date` week equals the due-week, so a materialized occurrence stops
  ghosting — **even when bound to a day in a later week** (the carried case). "carried N weeks"
  (derived from `origin_date`) then correctly counts from when the occurrence was *due*.
- `materialize_occurrence` is **REST-only, not registered** in `item_actions.rb` (mirrors
  `reconcile`): the action registry invokes fixed positional param lists via
  `ActionStep.process`, and the optional `date` has no composition use yet.

**Rationale**: Reusing `origin_date` keeps PR 13 additive and schema-stable while making the
whole "ghost becomes a real placement, then rides the existing placement endpoints" loop work
with no new field. After materialization the occurrence is an ordinary `Placement`, so
bind/complete/skip/defer/delete need no recurring-specific code.

**Deferred**: FE (rule editor, ghost surfacing, touch-routing) → PR 14; reconcile-expiry of
persisted recurring occurrences, relative cadence, monthly/date/week-phase anchoring, splitting,
"just this once" → later.

---

## 2026-08-05 — Bound a recurrence going forward (`end_date`)

**Context**: A live rule had no way to end a series — the only "clear my calendar for the
future" path was deleting the whole rule (also losing the fact it ever recurred), and it
wasn't discoverable. Added an optional upper bound mirroring the existing `start_date` lower
bound.

**Decision**:
- `Recurrence` (`src/type/recurrence.rb`) gains an optional `end_date` (nil => open-ended),
  validated by a shared nil-allowed `date_valid?` (renamed from `start_date_valid?`). Added
  `Recurrence.end_date_of`.
- `occurrences_for_week` (`src/actions/occurrences.rb`) gains a `past_end?` gate: nothing is
  emitted once **either** the occurrence's `due_week` **or** the visible `target_week` is past
  the end_date's grid week. Gating `due_week` stops any new period starting after the end;
  gating `target_week` also **cuts the carry** — after the end there is no next due-week to
  expire a still-carrying occurrence, so an unfinished one would otherwise linger forever.
- Read-side only: no Placement change, no new endpoint. The rule is edited through the generic
  item `PUT`; already-persisted placements before the end remain as history.

**Rationale**: An `end_date` (stop after a boundary, keep history) is a distinct need from
`active:false` (pause everything, reversible). Cutting the carry at the end week is the literal
"clear the future" the owner asked for; the alternative (let the final in-window occurrence
carry forever) contradicts that intent and has no natural expiry.

**Deferred**: monthly/relative cadence + anchoring still deferred; multi-day-per-week (one rule
firing on several weekdays) is designed but deferred — it requires occurrence identity to
include the weekday, not just the due-week.

---

## 2026-08-06 — Every-N-weeks actually skips weeks (phase, carry, and two staging leaks)

**Context**: End-to-end testing of "every 2 weeks on Wednesday" showed the Wednesday card in the
due weeks **and** a floating copy, badged "carried 1w", in every week between them. Tracing it
found two independent defects plus two more sitting on the same path.

**Decision**:
- `occurrences_for_week` gains a **`future_carry?`** gate (between `past_end?` and
  `occurrence_touched?`): a *carried* occurrence is emitted only for a `target_week` at or
  before the `as_of` week. Looking ahead, an occurrence appears only in the week it is actually
  due; the current week's carry (design §2.5) is untouched.
- `occurrence_touched?` gains a **windowed `staged_week` fallback** for a placement that is both
  dayless and origin-less (i.e. manually staged via `create_floating_placement`, which stamps
  neither): it owns the occurrence when `due_week <= staged_week <= target_week`. A bare
  `staged_week == due_week` was rejected — it re-opens the duplicate in the carry case; staged
  *before* the due-week must NOT suppress, or a stale pile entry silently swallows a later
  occurrence.
- `materialize_occurrence` takes an optional **`staged_week`** (body field on
  `POST /api/items/:id/occurrences`), stamped on an undated materialization and defaulting to
  `period_start`; the idempotent branch re-stamps a floating placement. A dated materialization
  stays unstamped.
- The phase anchor itself is a **frontend** fix (games-lists `docs/DECISIONS.md`): the rule
  editor now always writes `start_date`. `anchor_week`'s `rule['start_date'] || as_of` fallback
  stays as the legacy path.

**Rationale**: Carry-until-due means "it was due, you didn't get to it, it's still on your
plate" — a claim about elapsed time. Projected forward it asserts you *will* fail to do next
week's, which pre-fills the planner with speculative work and makes an every-N-weeks rule read
as weekly. `as_of` was already threaded through the materializer for exactly this kind of
now-relative judgment and simply wasn't consulted. The two staging fixes are the same class of
bug in the other direction: an unstamped `staged_week` matched **no** week, so a materialized
floating occurrence vanished from the pile and `reconcile` could never release it (`floating_past`
is false when nil) — an invisible, immortal row; and a manually staged placement that couldn't be
recognized as owning its occurrence showed the item twice in one week.

**Deferred**: `occurrence_touched?` still ignores `resolution`, so a reconcile-`lapsed`
placement permanently suppresses its due-week occurrence. Left alone this pass — it needs a
decision about whether a lapsed recurring occurrence should re-ghost, which is a design
question, not a bug.

---

## 2026-08-07 — The day range read returns placements, not item ids

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

---

## In Progress

*(Add notes here when starting a work session — what you're building, what's broken, what's next)*
