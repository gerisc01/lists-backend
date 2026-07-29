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
# Scope (PR 12): absolute weekly cadence, floating + fixed-day anchoring. Relative
# cadence, monthly/date/week-phase anchoring, splitting, and "just this once"
# overrides are deferred (PR 13/14).
#
# Invariants enforced here (design §2.5):
#   * At most ONE live occurrence per rule per week — the most recent due-week at or
#     before the target week. Older occurrences auto-expire (never surfaced).
#   * Carry-until-due — an untouched occurrence from an earlier due-week keeps
#     surfacing in each week's staging until the next occurrence comes due.
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

    due_week = current_due_week(rule, target_week, as_of)
    next if due_week.nil?                                   # rule hasn't started yet
    next if occurrence_touched?(item.id, due_week, target_week)  # a real Placement owns it

    ghosts << build_ghost(item, rule, due_week, target_week, as_of)
  end
end

# The most recent due-week (as a Date) at or before `target_week`, or nil if the rule
# has not started by then. Due-weeks are `interval` weeks apart, phased from the
# anchor week (the grid week containing the rule's start_date; falls back to the
# as_of week when start_date is absent — meaningful mainly for interval 1).
def current_due_week(rule, target_week, as_of)
  anchor = anchor_week(rule, target_week, as_of)
  weeks_since = ((target_week - anchor).to_i / 7)
  return nil if weeks_since.negative?

  interval = rule['interval']
  due_index = (weeks_since / interval) * interval          # floor to a due multiple
  anchor + (due_index * 7)
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
def occurrence_touched?(item_id, due_week, grid_ref)
  Placement.for_item(item_id).any? do |placement|
    anchor = placement.origin_date || placement.date
    next false if anchor.nil?                              # a dayless placement with no origin
    week_start_of(::Date.parse(anchor), grid_ref) == due_week
  end
end

# A ghost occurrence, shaped like a Placement so PR 13's read path can merge it into
# the same day/staging view (plus ghost provenance). `carried` marks an occurrence
# riding forward from an earlier due-week; `origin_date` anchors the "carried N weeks"
# derivation the staging UI already does off origin_date.
def build_ghost(item, rule, due_week, target_week, as_of)
  carried = due_week < target_week
  anchor = rule['anchor']

  date, floating, origin =
    if anchor['kind'] == 'fixed-day'
      fixed = due_week + weekday_offset(due_week, anchor['weekday'])
      if carried
        # A slipped fixed-day occurrence re-floats (mirrors reconcile's carry of a
        # lapsed dated task), keeping its original day as the origin anchor.
        [nil, true, fixed.iso8601]
      else
        [fixed.iso8601, false, fixed.iso8601]
      end
    else # floating: always dayless, anchored to the due-week's first day
      [nil, true, due_week.iso8601]
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
