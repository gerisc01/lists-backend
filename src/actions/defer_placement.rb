require 'date'
require_relative '../type/placement'

# Moves a floating placement to the week after `week_start`. Always exactly one week.
def defer_placement(placement_id, week_start)
  raise ListError::BadRequest, "a week_start is required" if week_start.to_s.empty?

  placement = Placement.get(placement_id)
  raise ListError::NotFound, "placement id '#{placement_id}' not found" if placement.nil?

  placement.staged_week = (Date.parse(week_start) + 7).iso8601
  placement.validate
  placement.save!
  return placement
end
