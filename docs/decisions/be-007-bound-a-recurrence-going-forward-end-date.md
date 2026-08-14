---
id: be-007
date: 2026-08-05
title: "Bound a recurrence going forward (`end_date`)"
feature: recurrence
repo: be
---

# Bound a recurrence going forward (`end_date`)

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
