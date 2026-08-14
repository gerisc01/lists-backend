---
id: be-008
date: 2026-08-06
title: "Every-N-weeks actually skips weeks (phase, carry, and two staging leaks)"
feature: recurrence
repo: be
---

# Every-N-weeks actually skips weeks (phase, carry, and two staging leaks)

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
