require 'date'
require_relative '../type/placement'

# Defer a floating placement one week (design.md §4.4). "Not this week, but yes next
# week": the placement drops out of *this* week's staging and reappears next week.
# Strictly +1 week — the server computes the target, so a client can't turn Defer
# into an arbitrary-duration snooze (longer than a week is Skip or Delete).
#
# Under the weekly-plan reframe (docs/DECISIONS.md) staged_week is the single week
# anchor, so Defer simply moves it forward one week: staged_week := week_start + 7.
# The pile read (floating_for_collections) then shows the placement exactly when the
# current week reaches that value — no separate not_before marker or client filter.
#
# `week_start` is the client's current-week start (it owns the week-start-day), so the
# +1-week target is computed against the same start the pile read compares against.
# Server-authoritative primitive, registry-registered, fronted by a thin endpoint.
def defer_placement(placement_id, week_start)
  raise ListError::BadRequest, "a week_start is required" if week_start.to_s.empty?

  placement = Placement.get(placement_id)
  raise ListError::NotFound, "placement id '#{placement_id}' not found" if placement.nil?

  placement.staged_week = (Date.parse(week_start) + 7).iso8601
  placement.validate
  placement.save!
  placement
end
