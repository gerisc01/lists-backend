---
id: be-011
date: 2026-08-10
title: "Monthly cadence rides the week grid; anchors are jointly validated with cadence"
feature: recurrence
repo: be
---

# Monthly cadence rides the week grid; anchors are jointly validated with cadence

`CADENCES` gains `monthly`, with two new anchor kinds: `date` (`{'kind' => 'date', 'day' => 1..31}`,
"the 3rd") and `week-of-month` (`{'kind' => 'week-of-month', 'week' => 1..5}`, dayless within
that week of the month). The materializer keeps its entire week-grid contract — `past_end?`,
`future_carry?`, `occurrence_touched?`, carry, and `period_start` are untouched. Only the due-period
computation branches on cadence: compute the monthly due *date*, then map it onto the caller's grid
with the existing `week_start_of`.

**The due period is week-indexed, not month-indexed.** The live occurrence is the latest due date
whose *grid week* is at or before the target week. Indexing by due month instead would expire an
untouched occurrence at the calendar month boundary rather than at the week its successor is actually
due: a day-15 rule's Aug 15 falls in the week of Aug 10, so standing in the week of Aug 3 — already
August — July's occurrence is still the one on your plate. Month-indexing would hand over August's a
week early and silently eat July's carry.

**Week-of-month is a NUMBER (1-5), not a `first`/`last` pair.** It mirrors day-of-month one unit
coarser: pick a unit, step a number, and an out-of-range number clamps to the month's last rather
than skipping the month. Verified across 2024-2032 on both a Monday and a Sunday grid, a month
spans exactly **4 or 5** majority weeks — never 3 or 6 — so weeks 1-4 never clamp and **week 5
always resolves to the month's last week**. That makes numbering a strict superset of the
first/last pair it replaced, with no separate "last" option to choose.

**Week N resolves to the Nth MAJORITY week** — the week containing the 4th, plus N-1 weeks — not
the week containing the 1st. The naive definition breaks on real calendars: Nov 1 2026 is a Sunday,
so November's "first week" would start Oct 26 and be six sevenths October; Aug 31 2026 is a Monday,
so August's "last week" would start Aug 31 and be six sevenths September. Majority weeks **tile the
calendar exactly** (zero gaps or overlaps across nine years), which is what makes "N-1 weeks past
the first" correct, and capping the surrogate date at the 4th-from-last clamps week 5 with no
week-counting and no grid reference. The minimum gap between consecutive occurrences stays 28 days
for every week number, so the no-collision argument still holds. The 4th and 4th-from-last are
internal surrogate dates that only ever feed `week_start_of` — these ghosts are dayless, so the
surrogate never surfaces.

**An unrecognised anchor yields no occurrence rather than raising.** A shape from a later build, or
one left behind by this rename, must not take down the whole week's read for every rule beside it.

**Day-of-month overflow clamps** to the month's last day (the 31st lands on Feb 28) rather than
skipping the month, which would leave a period with no occurrence and nothing to expire the previous
one. The clamp is recomputed per month from a first-of-month cursor shifted by the full `k * interval`,
because **chaining `Date#>>` is lossy**: `Jan 31 >> 1 >> 1` is Mar 28, but `>> 2` is Mar 31.

**Cadence and anchor are jointly validated** through `ANCHOR_KINDS_BY_CADENCE`, replacing the flat
`ANCHOR_KINDS`. Plain `floating` stays weekly-only and monthly requires `date` or `week-of-month`
(design §2.5) — a floating monthly occurrence would have to answer "which week of the month?", and
the two monthly anchors exist precisely to sidestep that. `anchor_valid?` takes the cadence, called
after the `CADENCES` guard so the cadence is always known.

**`start_date` is a floor for monthly but only a phase hint for weekly.** Present, it advances the
first monthly occurrence by one month when that month's anchor date has already passed — a rule
authored on the 20th with a day-5 anchor must not appear instantly as a two-week-old carry. It steps
by one month, not by `interval`, so "every 3 months on the 5th" authored Aug 10 first fires Sep 5
rather than Nov 5. Absent, there is no floor at all: `as_of` supplies phase only, mirroring the weekly
fallback where the week you are standing in is a due week. The asymmetry is deliberate — a weekly
snap-back is under 7 days, a monthly one would be up to 30.

**`interval` is cadence-relative** (weeks under weekly, months under monthly). One field, no schema
branch; the unit is resolved by the cadence at read time and in the UI label.

`current_due_week` became `current_occurrence`, returning an `Occurrence(week, date)` struct. This was
forced, not cosmetic: a monthly `date` anchor's day is **not** recoverable from its grid week — Sep 1
2026 sits in the week starting Aug 31 — whereas a weekday always sits inside its own week, which is
why the weekly path never needed it. It made `build_ghost` smaller, branching on "is there a pinned
date" instead of on the anchor kind, and weekly output is byte-identical (the unchanged weekly test
suite is the regression signal).

**Known, not changed here:** monthly stretches the carry window from about one week to about four,
which makes two existing behaviours much more visible — `occurrence_touched?`'s staged-placement
branch can suppress a ghost for up to four weeks off one manually staged card, and `past_end?`'s
`target_week > end_week` cut kills a carry after a week instead of letting it run its period. Both are
the existing contract, just louder.
