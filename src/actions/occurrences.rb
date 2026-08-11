require 'date'
require_relative '../type/item'
require_relative '../type/placement'
require_relative '../type/scheduling'
require_relative '../type/recurrence'

# The recurrence MATERIALIZER (design.md §2.5). The rule is the source of truth;
# untouched occurrences are GHOSTS — computed for the visible week, never stored — so
# a handful of rules cost nothing to render and no rows spawn for occurrences you
# never touch. A Placement row persists only once an occurrence is TOUCHED (placed,
# completed, carried, or skipped); this function is the read side that computes what
# hasn't been touched yet.
#
# Modeled on reconcile.rb: a PURE function with an injectable `as_of` for
# deterministic tests, logic-here / trigger-separate, and NOT registered in
# item_actions.rb (like reconcile, it is a read/compute, not a mutation). PR 12 is
# SHADOW: nothing calls this yet and nothing is surfaced. PR 13 wires it into the
# placement read path and makes a touch persist a real Placement.
#
# Scope: absolute cadence, weekly (floating + fixed-day) and monthly (date +
# week-of-month). Relative cadence, splitting, and "just this once" overrides are deferred.
#
# Invariants enforced here (design §2.5):
#   * At most ONE live occurrence per rule per week — the most recent due-week at or
#     before the target week. Older occurrences auto-expire (never surfaced).
#   * Carry-until-due — an untouched occurrence from an earlier due-week keeps
#     surfacing in each week's staging until the next occurrence comes due. Carry is
#     PAST-TENSE ONLY (future_carry?): it never projects into a week later than the
#     current one, where "you didn't get to it" isn't yet true of anything.
#   * Touched => real — if a Placement already exists for the occurrence's period,
#     no ghost is emitted (the persisted row represents it instead). Dedup reuses the
#     placement's immutable origin_date/date; no Placement schema change this slice.
#
# `week_start` and `as_of` are 'YYYY-MM-DD' strings. The caller owns the week grid
# (which weekday a week starts on); `week_start` both selects the target week and
# defines that grid — every valid week start is `week_start ± 7n`.
def occurrences_for_week(collection_ids, week_start, as_of: Date.today.iso8601)
  target_week = ::Date.parse(week_start)

  Item.list.each_with_object([]) do |item, ghosts|
    next unless Scheduling.active_recurrence?(item)
    rule = Scheduling.recurrence_of(item.json['scheduling'])
    next unless collection_ids.include?(rule['collection_id'])

    occurrence = current_occurrence(rule, target_week, as_of)
    next if occurrence.nil?                                 # rule hasn't started yet
    due_week = occurrence.week
    next if past_end?(rule, due_week, target_week)          # series ended (end_date)
    next if future_carry?(due_week, target_week, as_of)     # carry is past-tense only
    next if occurrence_touched?(item.id, due_week, target_week, target_week)  # a real Placement owns it

    ghosts << build_ghost(item, rule, occurrence, target_week)
  end
end

# The live occurrence a rule surfaces in the target week: its PERIOD (the grid week that
# keys dedup and period_start) and, for a pinned anchor, the exact day it falls on.
# `date` nil means a dayless anchor (weekly floating, monthly week-of-month).
#
# The two are kept together because a monthly `date` anchor's day is NOT recoverable from
# its grid week — Sep 1 2026 sits in the week starting Aug 31, so a due week of Aug 31
# could mean either. A weekday always sits inside its own grid week, which is why the
# weekly path never needed this.
Occurrence = Struct.new(:week, :date)

# The live occurrence at or before `target_week`, or nil if the rule has not started by
# then. Cadence decides only how the due period is computed; everything downstream works
# off the grid week either way.
def current_occurrence(rule, target_week, as_of)
  if rule['cadence'] == 'monthly'
    monthly_occurrence(rule, target_week, as_of)
  else
    weekly_occurrence(rule, target_week, as_of)
  end
end

# Weekly due-weeks are `interval` weeks apart, phased from the anchor week (the grid week
# containing the rule's start_date; falls back to the as_of week when start_date is
# absent — meaningful mainly for interval 1).
def weekly_occurrence(rule, target_week, as_of)
  anchor = anchor_week(rule, target_week, as_of)
  weeks_since = ((target_week - anchor).to_i / 7)
  return nil if weeks_since.negative?

  interval = rule['interval']
  due_index = (weeks_since / interval) * interval          # floor to a due multiple
  due_week = anchor + (due_index * 7)
  pinned = rule['anchor']['kind'] == 'fixed-day' ? due_week + weekday_offset(due_week, rule['anchor']['weekday']) : nil
  Occurrence.new(due_week, pinned)
end

# Monthly occurrences are `interval` months apart, and the live one is the latest whose
# GRID WEEK is at or before the target — not the latest due MONTH. Month-indexing would
# expire an untouched occurrence at the calendar month boundary instead of at the week its
# successor is actually due: a day-15 rule's Aug 15 falls in the week of Aug 10, so on Aug
# 3 July's occurrence is still the live one and must keep carrying.
#
# Month arithmetic gets within one step of the answer (a due date's week can start in the
# previous month), so each correction below runs at most once. That is safe because
# consecutive due dates of one rule are always >= 28 days apart — the tightest case is Jan
# 31 -> Feb 28 — so due weeks strictly increase by >= 4 weeks and the search is unambiguous.
def monthly_occurrence(rule, target_week, as_of)
  anchor = rule['anchor']
  # A rule whose anchor this version doesn't understand (a shape from a later build, or one
  # left behind by a rename) yields no occurrences instead of raising: one bad rule must not
  # take down the whole week's read for every other rule beside it. Checked before anything
  # else, because first_due_month resolves a due date too.
  return nil if monthly_due_date(anchor, target_week).nil?

  origin = first_due_month(rule, as_of)
  interval = rule['interval']
  # Always shift the first-of-month cursor by the full k*interval: chaining Date#>> is
  # lossy, because clamping sticks (Jan 31 >> 1 >> 1 is Mar 28, but >> 2 is Mar 31).
  week_of = ->(k) { week_start_of(monthly_due_date(anchor, origin >> (k * interval)), target_week) }

  months_since = (target_week.year * 12 + target_week.month) - (origin.year * 12 + origin.month)
  index = months_since / interval                          # Integer#/ floors toward -inf
  index -= 1 while index >= 0 && week_of.call(index) > target_week
  index += 1 while week_of.call(index + 1) <= target_week
  return nil if index.negative?

  due = monthly_due_date(anchor, origin >> (index * interval))
  Occurrence.new(week_start_of(due, target_week), anchor['kind'] == 'date' ? due : nil)
end

# A monthly rule's due date within the month that `month_ref` (a first-of-month Date)
# starts, or nil if the anchor is one this version doesn't understand (the caller then
# emits nothing for the rule, rather than the whole week's read failing).
#
# A `date` anchor clamps an overflowing day to the month's last, so "the 31st" lands on
# Feb 28 rather than skipping February.
#
# A `week-of-month` anchor resolves to a SURROGATE date whose only job is to pick a grid
# week: the 4th, and the 4th-from-last, are exactly the days that select a MAJORITY week —
# the week containing that date unless fewer than four of its days belong to the month.
# The naive "week containing the 1st" would make November 2026's first week the week of
# Oct 26 (six October days), and August 2026's last week the week of Aug 31 (six September
# days). Majority weeks tile the calendar exactly, so week N is simply N-1 weeks past the
# first one, and capping the surrogate at the 4th-from-last CLAMPS week 5 to the month's
# last week with no week-counting: verified against both a Monday and a Sunday grid across
# 2024-2032. A month spans exactly 4 or 5 majority weeks, so weeks 1-4 never clamp and
# week 5 always lands on the last one. The surrogate never surfaces — these ghosts are
# dayless.
def monthly_due_date(anchor, month_ref)
  last = ::Date.new(month_ref.year, month_ref.month, -1)
  case anchor['kind']
  when 'date'
    ::Date.new(month_ref.year, month_ref.month, [anchor['day'], last.day].min)
  when 'week-of-month'
    [month_ref + 3 + ((anchor['week'] - 1) * 7), last - 3].min
  end
end

# The month a monthly series is phased from, as a first-of-month Date.
#
# An explicit start_date is a FLOOR, not just a phase hint: a rule authored on the 20th
# with a day-5 anchor must not immediately surface the 5th as a two-week-old carry, so it
# steps to the next month. It steps by ONE month rather than by `interval`, which re-bases
# the phase onto the first month that actually fires — "every 3 months on the 5th"
# authored Aug 10 should first fire Sep 5, not Nov 5.
#
# With no start_date there is no floor: as_of supplies phase only. That mirrors the weekly
# fallback, where the week you are standing in is a due week — clamping forward there
# would hide a day-15 rule for a month whenever it was read after the 15th.
def first_due_month(rule, as_of)
  seed = ::Date.parse(rule['start_date'] || as_of)
  month = ::Date.new(seed.year, seed.month, 1)
  return month if rule['start_date'].nil?

  monthly_due_date(rule['anchor'], month) < seed ? month >> 1 : month
end

# Has the series ended by this week? A rule may carry an optional end_date (the upper
# bound mirroring start_date's lower bound). Nothing is emitted once EITHER the
# occurrence's due-week OR the visible target week is past the end_date's grid week.
# Gating due_week stops any new period starting after the end; gating target_week also
# cuts the carry — after the end there is no next due-week to expire a still-carrying
# occurrence, so an unfinished one would otherwise linger forever. Both past the end
# means "clear the future" while past placements (already persisted) remain as history.
def past_end?(rule, due_week, target_week)
  end_date = Recurrence.end_date_of(rule)
  return false if end_date.nil?

  end_week = week_start_of(::Date.parse(end_date), target_week)
  due_week > end_week || target_week > end_week
end

# Carry-until-due is a claim about weeks you have LIVED THROUGH ("it was due, you didn't
# get to it, it's still on your plate"), so it must not project forward. Looking ahead,
# an occurrence appears only in the week it is actually due — the off weeks of an
# every-N-weeks rule come back empty instead of pre-filled with a copy you're assumed to
# have missed. Only a *carry* is gated: a ghost due in the target week emits however far
# ahead that week is, and the current week's carry (design §2.5) is untouched.
def future_carry?(due_week, target_week, as_of)
  return false unless due_week < target_week          # not a carry at all
  target_week > week_start_of(::Date.parse(as_of), target_week)
end

# Snap the rule's phase anchor onto the caller's week grid.
def anchor_week(rule, target_week, as_of)
  seed = rule['start_date'] || as_of
  week_start_of(::Date.parse(seed), target_week)
end

# The grid week-start (a Date) that `date` falls in, using `grid_ref` (any valid week
# start) to define the grid. Rounds down to the nearest grid week boundary.
def week_start_of(date, grid_ref)
  weeks = ((date - grid_ref).to_i / 7.0).floor
  grid_ref + (weeks * 7)
end

# Has this occurrence (the rule's due-week) already been touched? A persisted
# Placement for the item whose period (its immutable origin_date, else its date)
# lands in the same grid week as `due_week` represents the occurrence — completed,
# skipped, carried, or merely placed — so no ghost is emitted for it.
#
# A placement that is BOTH dayless and origin-less has no period of its own: that is a
# MANUALLY STAGED one (create_floating_placement stamps only staged_week), so fall back
# to the week it was staged into. It represents this occurrence when it was staged at or
# after the occurrence came due and is still inside the occurrence's live window — i.e.
# it IS the card already on screen, and emitting a ghost beside it would double the item.
# Staged BEFORE the due-week it is a stale pile entry from an earlier plan and owns
# nothing, so a later occurrence still ghosts as normal.
def occurrence_touched?(item_id, due_week, target_week, grid_ref)
  Placement.for_item(item_id).any? do |placement|
    anchor = placement.origin_date || placement.date
    if anchor.nil?
      next false if placement.staged_week.nil?
      staged = week_start_of(::Date.parse(placement.staged_week), grid_ref)
      next staged >= due_week && staged <= target_week
    end
    week_start_of(::Date.parse(anchor), grid_ref) == due_week
  end
end

# A ghost occurrence, shaped like a Placement so PR 13's read path can merge it into
# the same day/staging view (plus ghost provenance). `carried` marks an occurrence
# riding forward from an earlier due-week; `origin_date` anchors the "carried N weeks"
# derivation the staging UI already does off origin_date.
def build_ghost(item, rule, occurrence, target_week)
  due_week = occurrence.week
  carried = due_week < target_week
  pinned = occurrence.date

  date, floating, origin =
    if pinned.nil?
      # A dayless anchor (weekly floating / monthly week-of-month) is anchored to the
      # due-week's first day.
      [nil, true, due_week.iso8601]
    elsif carried
      # A slipped pinned occurrence re-floats (mirrors reconcile's carry of a lapsed
      # dated task), keeping its original day as the origin anchor.
      [nil, true, pinned.iso8601]
    else
      [pinned.iso8601, false, pinned.iso8601]
    end

  {
    'ghost' => true,
    'rule_item_id' => item.id,
    'item_id' => item.id,
    'collection_id' => rule['collection_id'],
    'date' => date,
    'floating' => floating,
    'origin_date' => origin,
    'period_start' => due_week.iso8601,
    'carried' => carried,
  }
end

# Days from a week-start Date to the given weekday (Ruby Date#wday, 0=Sun..6=Sat)
# within that same grid week.
def weekday_offset(week_start, weekday)
  (weekday - week_start.wday) % 7
end
