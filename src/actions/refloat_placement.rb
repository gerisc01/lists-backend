require 'date'
require_relative '../type/placement'

# Takes a placement off its day and back into `week_start`'s pile. Clears any resolution — reconcile
# may have lapsed it, and the pile hides resolved placements. Keeps origin_date.
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
  return placement
end
