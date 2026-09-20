require 'date'
require_relative '../type/item'
require_relative '../type/placement'
require_relative '../type/scheduling'
require_relative '../type/recurrence'

# Ghosts: the untouched occurrences of every active rule for one week, computed and never stored.
# `week_start` also defines the caller's week grid — every week start is `week_start ± 7n`.
def occurrences_for_week(collection_ids, week_start, as_of: Date.today.iso8601)
  target_week = ::Date.parse(week_start)

  return Item.list.each_with_object([]) do |item, ghosts|
    next if !Scheduling.active_recurrence?(item)
    rule = Scheduling.recurrence_of(item.json['scheduling'])
    next if !collection_ids.include?(rule['collection_id'])

    occurrence = current_occurrence(rule, target_week, as_of)
    next if occurrence.nil?
    due_week = occurrence.week
    next if past_end?(rule, due_week, target_week)
    next if future_carry?(due_week, target_week, as_of)
    next if occurrence_touched?(item.id, due_week, target_week, target_week)

    ghosts << build_ghost(item, rule, occurrence, target_week)
  end
end

# `week` is the grid week it's due in; `date` is its day, or nil when the anchor is dayless. A monthly
# date can't be recovered from its week: Sep 1 2026 falls in the week of Aug 31.
Occurrence = Struct.new(:week, :date)

# The latest occurrence due at or before `target_week`, or nil if the rule hasn't started.
def current_occurrence(rule, target_week, as_of)
  if rule['cadence'] == 'monthly'
    return monthly_occurrence(rule, target_week, as_of)
  else
    return weekly_occurrence(rule, target_week, as_of)
  end
end

# Due weeks are `interval` weeks apart, counted from the week of start_date (else as_of).
def weekly_occurrence(rule, target_week, as_of)
  anchor = anchor_week(rule, target_week, as_of)
  weeks_since = ((target_week - anchor).to_i / 7)
  return nil if weeks_since.negative?

  interval = rule['interval']
  due_index = (weeks_since / interval) * interval
  due_week = anchor + (due_index * 7)
  pinned = rule['anchor']['kind'] == 'fixed-day' ? due_week + weekday_offset(due_week, rule['anchor']['weekday']) : nil
  return Occurrence.new(due_week, pinned)
end

# The live one is the latest whose grid WEEK is at or before the target, not the latest due month:
# Aug 15 falls in the week of Aug 10, so on Aug 3 July's occurrence is still live.
def monthly_occurrence(rule, target_week, as_of)
  anchor = rule['anchor']
  # An unknown anchor yields nothing rather than raising, so one bad rule can't fail the whole read.
  return nil if monthly_due_date(anchor, target_week).nil?

  origin = first_due_month(rule, as_of)
  interval = rule['interval']
  # Shift by the full k*interval each time: chained Date#>> keeps its clamping (Jan 31 >> 1 >> 1 is Mar 28).
  week_of = ->(k) { week_start_of(monthly_due_date(anchor, origin >> (k * interval)), target_week) }

  months_since = (target_week.year * 12 + target_week.month) - (origin.year * 12 + origin.month)
  index = months_since / interval
  # Month math lands within one step; due dates are >= 28 days apart, so each loop runs at most once.
  index -= 1 while index >= 0 && week_of.call(index) > target_week
  index += 1 while week_of.call(index + 1) <= target_week
  return nil if index.negative?

  due = monthly_due_date(anchor, origin >> (index * interval))
  return Occurrence.new(week_start_of(due, target_week), anchor['kind'] == 'date' ? due : nil)
end

# nil for an unknown anchor. Week N is the Nth week with at least four days in the month: the week
# containing the 4th, plus N-1 weeks, capped at the week containing the 4th-from-last.
def monthly_due_date(anchor, month_ref)
  last = ::Date.new(month_ref.year, month_ref.month, -1)
  return case anchor['kind']
  when 'date'
    ::Date.new(month_ref.year, month_ref.month, [anchor['day'], last.day].min)
  when 'week-of-month'
    [month_ref + 3 + ((anchor['week'] - 1) * 7), last - 3].min
  end
end

# A start_date is a floor: if its month's due day has already passed, the series starts next month.
# Without one, as_of sets the phase only.
def first_due_month(rule, as_of)
  seed = ::Date.parse(rule['start_date'] || as_of)
  month = ::Date.new(seed.year, seed.month, 1)
  return month if rule['start_date'].nil?

  return monthly_due_date(rule['anchor'], month) < seed ? month >> 1 : month
end

# Past the end once either the due week or the target week is after end_date's week. Checking the
# target week stops a last occurrence from carrying forever.
def past_end?(rule, due_week, target_week)
  end_date = Recurrence.end_date_of(rule)
  return false if end_date.nil?

  end_week = week_start_of(::Date.parse(end_date), target_week)
  return due_week > end_week || target_week > end_week
end

# An untouched occurrence carries into later weeks only up to the current one; future weeks show
# only what's due in them.
def future_carry?(due_week, target_week, as_of)
  return false if due_week >= target_week
  return target_week > week_start_of(::Date.parse(as_of), target_week)
end

def anchor_week(rule, target_week, as_of)
  seed = rule['start_date'] || as_of
  return week_start_of(::Date.parse(seed), target_week)
end

# `grid_ref` is any week start on the grid.
def week_start_of(date, grid_ref)
  weeks = ((date - grid_ref).to_i / 7.0).floor
  return grid_ref + (weeks * 7)
end

# A placement owns the occurrence if its origin_date (else date) is in the due week. A manually
# staged placement has neither, so it owns it if staged between the due week and the target week.
def occurrence_touched?(item_id, due_week, target_week, grid_ref)
  return Placement.for_item(item_id).any? do |placement|
    anchor = placement.origin_date || placement.date
    if anchor.nil?
      next false if placement.staged_week.nil?
      staged = week_start_of(::Date.parse(placement.staged_week), grid_ref)
      next staged >= due_week && staged <= target_week
    end
    week_start_of(::Date.parse(anchor), grid_ref) == due_week
  end
end

# Shaped like a placement. `carried` means it's due in an earlier week.
def build_ghost(item, rule, occurrence, target_week)
  due_week = occurrence.week
  carried = due_week < target_week
  pinned = occurrence.date

  date, floating, origin =
    if pinned.nil?
      [nil, true, due_week.iso8601]
    elsif carried
      # A carried pinned occurrence floats, keeping its day as origin_date.
      [nil, true, pinned.iso8601]
    else
      [pinned.iso8601, false, pinned.iso8601]
    end

  return {
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

# `weekday` is Date#wday (0 is Sunday).
def weekday_offset(week_start, weekday)
  return (weekday - week_start.wday) % 7
end
