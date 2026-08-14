---
id: be-006
date: 2026-07-29
title: "Recurring endpoints + the touch=>real seam (PR 13)"
feature: recurrence
repo: be
---

# Recurring endpoints + the touch=>real seam (PR 13)

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
