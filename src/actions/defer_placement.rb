require 'date'
require_relative '../type/placement'

# Defer a floating placement one week (design.md §4.4). "Not this week, but yes next
# week": the placement drops out of *this* week's staging and reappears next week.
# Strictly +1 week — the server computes the marker, so a client can't turn Defer
# into an arbitrary-duration snooze (longer than a week is Skip or Delete).
#
# Two writes, both on the floating placement (id-addressed like bind_placement,
# because a floating placement has no (item, date) natural key):
#   - not_before := start of NEXT week (week_start + 7). The client's render filter
#     hides the card until the current week reaches this marker.
#   - origin_date ||= week_start. This anchors the DERIVED "carried N weeks" count
#     (§4.4) at this week's start, so a task that was staged-but-never-dated and then
#     deferred still starts counting ("one number, not two" — the count increments
#     whether a task lapsed OR was actively deferred). A carried task already has an
#     origin_date, so ||= preserves it.
#
# `week_start` is the client's current-week start (it owns the week-start-day), passed
# in so the marker and the client-side visibility filter are computed against the same
# start. Server-authoritative primitive, registry-registered, fronted by a thin endpoint.
def defer_placement(placement_id, week_start)
  raise ListError::BadRequest, "a week_start is required" if week_start.to_s.empty?

  placement = Placement.get(placement_id)
  raise ListError::NotFound, "placement id '#{placement_id}' not found" if placement.nil?

  placement.origin_date ||= week_start
  placement.not_before = (Date.parse(week_start) + 7).iso8601
  placement.validate
  placement.save!
  placement
end
