require 'date'
require_relative '../type/placement'

# Re-float a dated placement back into staging (design §4.4, "take it off the day").
# The inverse of bind_placement: dated -> floating. "I still want this THIS week, just
# not on that day" — the placement drops its date and reappears in the current week's
# staging pile, from which it can be re-placed, deferred, or deleted.
#
# Distinct from resolving it (completed/skipped) and from deleting it: re-float is
# resolution-NEUTRAL. Crucially it CLEARS any resolution — reconcile stamps past-date
# placements `lapsed`, so a passed day's card may already read as resolved; re-floating
# must hand back a clean, open floating placement (else the pile read, which excludes
# resolved placements, would drop it). origin_date is left untouched — the immutable
# carry-forward anchor is explicitly "never overwritten when carry-forward re-floats it"
# (see Placement#origin_date), so a re-floated card keeps its original-date provenance.
#
# `week_start` is the client's current-week start (it owns the week-start-day), matching
# defer_placement — the re-floated placement stages into the week the planner is viewing.
# Server-authoritative primitive, registry-registered, fronted by a thin endpoint.
def refloat_placement(placement_id, week_start)
  raise ListError::BadRequest, "a week_start is required" if week_start.to_s.empty?

  placement = Placement.get(placement_id)
  raise ListError::NotFound, "placement id '#{placement_id}' not found" if placement.nil?

  placement.date = nil
  placement.floating = true
  placement.staged_week = week_start
  placement.resolution = nil
  placement.resolved_at = nil
  placement.validate
  placement.save!
  placement
end
