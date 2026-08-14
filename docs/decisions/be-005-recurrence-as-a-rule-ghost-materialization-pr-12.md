---
id: be-005
date: 2026-07-29
title: "Recurrence as a rule + ghost materialization (PR 12, shadow)"
feature: recurrence
repo: be
supersedes: be-002
---

# Recurrence as a rule + ghost materialization (PR 12, shadow)

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
